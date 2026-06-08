defmodule OpenSauceWeb.JobLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts
  alias OpenSauce.CRM
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <.form for={@form} id="job-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div style="display:flex;flex-direction:column;gap:20px;padding:4px 0 0;">

          <%!-- type --%>
          <div>
            <label class="dark-label" for={@form[:type].id}>Type</label>
            <select class="dark-select" name={@form[:type].name} id={@form[:type].id}>
              <option value="client_work" selected={@job_type == :client_work}>Client work</option>
              <option value="shift" selected={@job_type == :shift}>Shift</option>
              <option value="internal_work" selected={@job_type == :internal_work}>Internal work</option>
            </select>
          </div>

          <%!-- client_work fields --%>
          <div :if={@job_type == :client_work} style="display:flex;flex-direction:column;gap:20px;">
            <div>
              <label class="dark-label" for={@form[:engagement_id].id}>Engagement</label>
              <select class="dark-select" name={@form[:engagement_id].name} id={@form[:engagement_id].id}>
                <option value="">— none —</option>
                <option
                  :for={e <- @engagements}
                  value={e.id}
                  selected={to_string(@form[:engagement_id].value) == e.id}
                >
                  {engagement_label(e)}
                </option>
              </select>
            </div>

            <div>
              <label class="dark-label" for={@form[:service_category].id}>Service</label>
              <select class="dark-select" name={@form[:service_category].name} id={@form[:service_category].id}>
                <option value="">Select category</option>
                <option
                  :for={{label, val} <- service_category_options()}
                  value={val}
                  selected={to_string(@form[:service_category].value) == to_string(val)}
                >
                  {label}
                </option>
              </select>
              <span :for={msg <- @form[:service_category].errors} class="dark-field-error">{msg}</span>
            </div>

            <div :if={@gardens != []}>
              <label class="dark-label" for={@form[:garden_id].id}>Site</label>
              <select class="dark-select" name={@form[:garden_id].name} id={@form[:garden_id].id}>
                <option value="">— none —</option>
                <option
                  :for={g <- @gardens}
                  value={g.id}
                  selected={to_string(@form[:garden_id].value) == g.id}
                >
                  {garden_label(g)}
                </option>
              </select>
            </div>

            <div :if={@upstream_jobs != []}>
              <label class="dark-label" for="job_upstream_job_id">Cherry-pick materials from</label>
              <select class="dark-select" name="job[upstream_job_id]" id="job_upstream_job_id">
                <option value="">— none —</option>
                <option :for={j <- @upstream_jobs} value={j.id}>{upstream_job_label(j)}</option>
              </select>
            </div>
          </div>

          <%!-- internal_work fields --%>
          <div :if={@job_type == :internal_work}>
            <label class="dark-label" for={@form[:account_code].id}>Account code</label>
            <select class="dark-select" name={@form[:account_code].name} id={@form[:account_code].id}>
              <option value="">Select code</option>
              <option value="production" selected={@form[:account_code].value == :production}>Production</option>
              <option value="maintenance" selected={@form[:account_code].value == :maintenance}>Maintenance</option>
            </select>
            <span :for={msg <- @form[:account_code].errors} class="dark-field-error">{msg}</span>
          </div>

          <%!-- staff member --%>
          <div>
            <label class="dark-label" for={@form[:actor_id].id}>Staff member</label>
            <select class="dark-select" name={@form[:actor_id].name} id={@form[:actor_id].id}>
              <option value="">— none —</option>
              <option
                :for={m <- @members}
                value={m.user_id}
                selected={to_string(@form[:actor_id].value) == m.user_id}
              >
                {member_label(m)}
              </option>
            </select>
          </div>

          <%!-- date --%>
          <div>
            <label class="dark-label" for={@form[:scheduled_for].id}>Date</label>
            <input
              type="date"
              class="dark-input"
              name={@form[:scheduled_for].name}
              id={@form[:scheduled_for].id}
              value={Phoenix.HTML.Form.normalize_value("date", @form[:scheduled_for].value)}
            />
          </div>

          <%!-- notes --%>
          <div>
            <label class="dark-label" for={@form[:notes].id}>Notes</label>
            <textarea
              class="dark-textarea"
              name={@form[:notes].name}
              id={@form[:notes].id}
              rows="3"
            ><%= Phoenix.HTML.Form.normalize_value("textarea", @form[:notes].value) %></textarea>
          </div>

          <%!-- submit --%>
          <div style="padding-top:4px;">
            <.glow_button
              valid={form_valid?(@form, @job_type)}
              type="submit"
              phx-disable-with="Saving…"
            >
              {if @job, do: "Save changes", else: "Schedule"}
            </.glow_button>
          </div>

        </div>
      </.form>
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

  defp form_valid?(form, :client_work) do
    form[:service_category].value not in [nil, ""]
  end

  defp form_valid?(form, :internal_work) do
    form[:account_code].value not in [nil, ""]
  end

  defp form_valid?(_form, :shift), do: true

  defp service_category_options do
    [
      {"Installation", :installation},
      {"Delivery", :delivery},
      {"Pruning", :pruning},
      {"Consultation", :consultation},
      {"Design", :design},
      {"Opening", :opening},
      {"Winterization", :winterization},
      {"Maintenance", :maintenance}
    ]
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
