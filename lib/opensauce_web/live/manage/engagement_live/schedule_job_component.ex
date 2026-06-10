defmodule OpenSauceWeb.EngagementLive.ScheduleJobComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;">
      <.form
        for={@form}
        id="schedule-job-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:16px;"
      >
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div>
            <label class="dark-label" for="job_date">Job date</label>
            <input
              class="dark-input"
              type="date"
              id="job_date"
              name="job[date]"
              value={@form["date"]}
            />
          </div>
          <div>
            <label class="dark-label" for="job_service_category">Category</label>
            <select class="dark-select" id="job_service_category" name="job[service_category]">
              <option :for={{label, val} <- service_category_options()}
                value={val} selected={@form["service_category"] == val}>
                {label}
              </option>
            </select>
          </div>
        </div>

        <%!-- materials preview --%>
        <div :if={@to_date != nil}
          style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px;">
          <div style="display:flex;align-items:baseline;justify-content:space-between;margin-bottom:8px;">
            <span style="font-size:12px;font-weight:700;color:#9A9384;">
              Materials ({length(@preview_materials)})
            </span>
            <span style="font-size:11px;color:#6E675A;">
              {if @from_date, do: "#{@from_date} → #{@to_date}", else: "up to #{@to_date}"}
            </span>
          </div>
          <p :if={@preview_materials == []} style="font-size:13px;color:#6E675A;">
            No materials scheduled for this date.
          </p>
          <div style="display:flex;flex-direction:column;gap:5px;">
            <div :for={em <- @preview_materials} style="display:flex;align-items:center;gap:8px;">
              <span style="font-size:11px;color:#6E675A;width:68px;flex-shrink:0;">
                {em.scheduled_date}
              </span>
              <span style="font-size:13px;font-style:italic;color:#F4EFE2;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {catalog_item_title(em.supplier_catalog_item)}
              </span>
              <span style="font-size:12px;color:#9A9384;flex-shrink:0;">
                ×{em.quantity}
              </span>
            </div>
          </div>
        </div>

        <div>
          <.glow_button
            valid={@to_date != nil}
            type="submit"
            phx-disable-with="Creating…"
          >
            Create job
          </.glow_button>
        </div>
      </.form>
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
         {:ok, job} <-
           Orders.create_job(
             %{
               type: :client_work,
               garden_id: engagement.garden_id,
               engagement_id: engagement.id,
               scheduled_for: to_date,
               service_category: String.to_existing_atom(params["service_category"])
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
      |> Enum.filter(&(&1.scheduled_for != nil))
      |> Enum.map(& &1.scheduled_for)
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

  defp blank_form, do: to_form(%{"date" => "", "service_category" => "installation"}, as: "job")

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp service_category_options do
    [
      {"Installation", "installation"},
      {"Delivery", "delivery"},
      {"Pruning", "pruning"},
      {"Consultation", "consultation"},
      {"Design", "design"},
      {"Opening", "opening"},
      {"Winterization", "winterization"},
      {"Nursery run", "nursery_run"},
      {"Other", "other"}
    ]
  end

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
