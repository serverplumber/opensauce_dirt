defmodule OpenSauceWeb.EngagementLive.ScheduleJobComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.simple_form
        for={@form}
        id="schedule-job-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-2 gap-3">
          <.input field={@form[:date]} type="date" label="Job date" />
          <.input
            field={@form[:service_type]}
            type="select"
            label="Type"
            options={[
              {"Maintenance", "maintenance"},
              {"Installation", "installation"},
              {"Delivery", "delivery"},
              {"Consultation", "consultation"},
              {"Pruning", "pruning"},
              {"Open garden", "open_garden"},
              {"Winterize", "winterize_garden"}
            ]}
          />
        </div>

        <div :if={@to_date != nil} class="rounded-md border border-stone-200 p-3 space-y-2">
          <div class="flex items-baseline justify-between">
            <span class="text-sm font-medium text-stone-700">
              Scheduled materials ({length(@preview_materials)})
            </span>
            <span :if={@from_date} class="text-xs text-stone-400">
              {format_date(@from_date)} → {format_date(@to_date)}
            </span>
            <span :if={@from_date == nil} class="text-xs text-stone-400">
              up to {format_date(@to_date)}
            </span>
          </div>
          <div :if={@preview_materials == []} class="text-sm text-stone-400">
            No materials scheduled in this range.
          </div>
          <div class="space-y-1">
            <div
              :for={em <- @preview_materials}
              class="flex items-center gap-2 text-sm py-0.5"
            >
              <span class="text-stone-400 text-xs w-20 shrink-0">
                {format_date(em.scheduled_date)}
              </span>
              <span class="font-medium italic">{catalog_item_title(em.supplier_catalog_item)}</span>
              <span class="text-stone-500 text-xs">
                {em.quantity}{if em.supplier_catalog_item.format_description, do: " · #{em.supplier_catalog_item.format_description}"}
              </span>
            </div>
          </div>
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Creating...">Create job</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{engagement: engagement, current_member: member} = assigns, socket) do
    full =
      CRM.get_engagement_by_id!(
        engagement.id,
        actor: member,
        tenant: member.organisation_id,
        load: [materials: [:supplier_catalog_item], jobs: []]
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:engagement_full, full)
     |> assign(:from_date, from_date(full))
     |> assign(:to_date, nil)
     |> assign(:preview_materials, [])
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    form = to_form(params, as: "job")

    {to_date, preview} =
      case Date.from_iso8601(params["date"] || "") do
        {:ok, d} ->
          scheduled = scheduled_materials(socket.assigns.engagement_full.materials)
          materials = filter_by_date(scheduled, socket.assigns.from_date, d)
          {d, materials}

        _ ->
          {nil, []}
      end

    {:noreply, socket |> assign(form: form, to_date: to_date, preview_materials: preview)}
  end

  def handle_event("save", %{"job" => params}, socket) do
    member = socket.assigns.current_member
    engagement = socket.assigns.engagement_full

    with {:ok, to_date} <- Date.from_iso8601(params["date"] || ""),
         scheduled_at = DateTime.new!(to_date, ~T[09:00:00], "Etc/UTC"),
         {:ok, job} <-
           Orders.create_job(
             %{
               customer_id: engagement.customer_id,
               address_id: engagement.garden_id,
               engagement_id: engagement.id,
               scheduled_at: scheduled_at,
               service_type: String.to_existing_atom(params["service_type"])
             },
             actor: member,
             tenant: member.organisation_id
           ) do
      {scheduled, unscheduled} =
        Enum.split_with(engagement.materials, & &1.scheduled_date != nil)

      date_materials = filter_by_date(scheduled, socket.assigns.from_date, to_date)

      for em <- date_materials do
        Orders.create_job_material(
          %{job_id: job.id, supplier_catalog_item_id: em.supplier_catalog_item_id, quantity: em.quantity},
          actor: member,
          tenant: member.organisation_id
        )
      end

      if engagement.jobs == [] do
        for em <- unscheduled do
          Orders.create_job_material(
            %{job_id: job.id, supplier_catalog_item_id: em.supplier_catalog_item_id, quantity: em.quantity},
            actor: member,
            tenant: member.organisation_id
          )
        end
      end

      notify_parent({:job_created, job, length(date_materials)})
      {:noreply, socket}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid date.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create job.")}
    end
  end

  defp from_date(engagement) do
    last_job_date =
      engagement.jobs
      |> Enum.filter(&(&1.scheduled_at != nil))
      |> Enum.map(&DateTime.to_date(&1.scheduled_at))
      |> Enum.sort(Date)
      |> List.last()

    case {last_job_date, engagement.term_start} do
      {nil, nil} -> nil
      {nil, ts} -> ts
      {lj, nil} -> lj
      {lj, ts} -> if Date.compare(lj, ts) == :gt, do: lj, else: ts
    end
  end

  defp scheduled_materials(materials) do
    Enum.filter(materials, & &1.scheduled_date != nil)
  end

  defp filter_by_date(materials, from_date, to_date) do
    materials
    |> Enum.filter(fn em ->
      Date.compare(em.scheduled_date, to_date) in [:lt, :eq] &&
        (is_nil(from_date) || Date.compare(em.scheduled_date, from_date) in [:gt, :eq])
    end)
    |> Enum.sort_by(& &1.scheduled_date, Date)
  end

  defp blank_form, do: to_form(%{"date" => "", "service_type" => "maintenance"}, as: "job")

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp catalog_item_title(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name
      title -> title
    end
  end
end
