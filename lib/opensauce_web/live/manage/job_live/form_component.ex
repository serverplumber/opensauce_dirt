defmodule OpenSauceWeb.JobLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts
  alias OpenSauce.CRM
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="job-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-4">
          <.input
            field={@form[:type]}
            type="select"
            label="Type"
            options={[
              {"Client work", :client_work},
              {"Shift", :shift},
              {"Internal work", :internal_work}
            ]}
          />

          <%!-- Client work fields --%>
          <div :if={@job_type == :client_work} class="space-y-4">
            <.input
              field={@form[:engagement_id]}
              type="select"
              label="Engagement"
              options={[{"— none —", ""}] ++ Enum.map(@engagements, &{engagement_label(&1), &1.id})}
            />

            <.input
              field={@form[:service_category]}
              type="select"
              label="Service category"
              options={[
                {"Installation", :installation},
                {"Delivery", :delivery},
                {"Pruning", :pruning},
                {"Consultation", :consultation},
                {"Design", :design},
                {"Opening", :opening},
                {"Winterization", :winterization},
                {"Nursery run", :nursery_run},
                {"Other", :other}
              ]}
              prompt="Select category"
            />

            <.input
              field={@form[:garden_id]}
              type="select"
              label="Garden / Site"
              options={[{"— none —", ""}] ++ Enum.map(@gardens, &{garden_label(&1), &1.id})}
            />

            <.input
              :if={@upstream_jobs != []}
              name="job[upstream_job_id]"
              id="job_upstream_job_id"
              type="select"
              label="Cherry-pick materials from"
              options={[{"— none —", ""}] ++ Enum.map(@upstream_jobs, &{upstream_job_label(&1), &1.id})}
              value=""
            />
          </div>

          <%!-- Internal work fields --%>
          <div :if={@job_type == :internal_work}>
            <.input
              field={@form[:account_code]}
              type="select"
              label="Account code"
              options={[
                {"Production", :production},
                {"Maintenance", :maintenance}
              ]}
              prompt="Select code"
            />
          </div>

          <.input
            field={@form[:actor_id]}
            type="select"
            label="Staff member"
            options={[{"— none —", ""}] ++ Enum.map(@members, &{member_label(&1), &1.user_id})}
          />

          <.input field={@form[:scheduled_for]} type="date" label="Date" />

          <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">{if @job, do: "Save", else: "Create Job"}</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{job: job} = assigns, socket) do
    member = assigns.current_member

    engagements = load_engagements(member)
    members = load_members(member)

    current_type = (job && job.type) || :client_work
    engagement_id = job && job.engagement_id
    garden_id = job && job.garden_id

    gardens = gardens_for_engagement(engagements, engagement_id)

    upstream_jobs =
      if garden_id, do: load_upstream_jobs(garden_id, member), else: []

    form =
      if job do
        AshPhoenix.Form.for_update(job, :update,
          as: "job",
          actor: member,
          tenant: member.organisation_id
        )
      else
        AshPhoenix.Form.for_create(Orders.Job, :create,
          as: "job",
          actor: member,
          tenant: member.organisation_id
        )
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:engagements, engagements)
     |> assign(:members, members)
     |> assign(:gardens, gardens)
     |> assign(:upstream_jobs, upstream_jobs)
     |> assign(:job_type, current_type)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    job_type =
      case params["type"] do
        "client_work" -> :client_work
        "shift" -> :shift
        "internal_work" -> :internal_work
        _ -> :client_work
      end

    engagement_id = params["engagement_id"]
    gardens = gardens_for_engagement(socket.assigns.engagements, engagement_id)

    garden_id = params["garden_id"]

    upstream_jobs =
      if garden_id not in [nil, ""] do
        load_upstream_jobs(garden_id, socket.assigns.current_member)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:job_type, job_type)
     |> assign(:gardens, gardens)
     |> assign(:upstream_jobs, upstream_jobs)}
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    {upstream_job_id, job_params} = Map.pop(params, "upstream_job_id")

    case AshPhoenix.Form.submit(socket.assigns.form, params: job_params) do
      {:ok, job} ->
        move_materials_from_upstream(upstream_job_id, job, socket)
        notify_parent({:saved, job})

        {:noreply,
         socket
         |> put_flash(:info, "Job saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp move_materials_from_upstream(id, _job, _socket) when id in [nil, ""], do: :ok

  defp move_materials_from_upstream(upstream_job_id, job, socket) do
    member = socket.assigns.current_member

    upstream =
      Orders.get_job_by_id!(upstream_job_id,
        actor: member,
        tenant: member.organisation_id,
        load: [:materials]
      )

    Enum.each(upstream.materials, fn jm ->
      Orders.move_job_material!(jm, %{job_id: job.id},
        actor: member,
        tenant: member.organisation_id
      )
    end)
  end

  defp load_engagements(member) do
    CRM.list_engagements!(
      actor: member,
      tenant: member.organisation_id,
      load: [:garden, :customer]
    )
  rescue
    _ -> []
  end

  defp load_members(member) do
    Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)
  rescue
    _ -> []
  end

  defp load_upstream_jobs(garden_id, member) do
    Orders.list_jobs_at_garden!(garden_id,
      actor: member,
      tenant: member.organisation_id,
      load: [:materials]
    )
    |> Enum.filter(&(&1.materials != []))
  rescue
    _ -> []
  end

  defp gardens_for_engagement(_engagements, nil), do: []
  defp gardens_for_engagement(_engagements, ""), do: []

  defp gardens_for_engagement(engagements, engagement_id) do
    case Enum.find(engagements, &(&1.id == engagement_id)) do
      %{garden: garden} when not is_nil(garden) -> [garden]
      _ -> []
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp engagement_label(%{customer: nil} = e), do: "Engagement #{String.slice(e.id, 0, 8)}"

  defp engagement_label(%{customer: c, garden: nil}) do
    customer_name(c)
  end

  defp engagement_label(%{customer: c, garden: g}) do
    "#{customer_name(c)} — #{g.name || "unnamed site"}"
  end

  defp customer_name(c) do
    if c.company_name_nickname,
      do: c.company_name_nickname,
      else: "#{c.first_name} #{c.last_name}"
  end

  defp garden_label(addr), do: addr.name || "Unnamed site"

  defp member_label(m) do
    title = m.display_title
    if title && title != "", do: title, else: "Member"
  end

  defp upstream_job_label(%{service_category: nil, scheduled_for: nil}), do: "Job"

  defp upstream_job_label(%{service_category: cat, scheduled_for: nil}),
    do: Phoenix.Naming.humanize(cat)

  defp upstream_job_label(%{service_category: cat, scheduled_for: d}),
    do: "#{Phoenix.Naming.humanize(cat)} — #{Calendar.strftime(d, "%b %-d, %Y")}"
end
