defmodule OpenSauceWeb.JobLive.EventLogComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div :if={@events != []} class="space-y-1">
        <div :for={event <- @events} class="flex items-center gap-3 py-1.5 text-sm">
          <span class="font-medium text-stone-700 shrink-0">{event_type_label(event.data.type)}</span>
          <span class="text-stone-400 text-xs shrink-0">{format_event_time(event.timestamp)}</span>
          <span :if={event.note} class="text-stone-500 text-xs truncate">{event.note}</span>
        </div>
      </div>

      <div class={[@events != [] && "border-t border-stone-200 pt-4"]}>
        <.simple_form
          for={@form}
          id={"event-log-form-#{@job.id}"}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <div class="space-y-4">
            <div class="flex gap-4">
              <div class="flex-1">
                <.input field={@form[:timestamp]} type="datetime-local" label="Time" step="1800" />
              </div>
              <div class="w-36">
                <.input
                  type="number"
                  name="event[odometer_km]"
                  value={@odometer_km}
                  label="Odometer (km)"
                  min="0"
                  step="1"
                />
              </div>
            </div>
            <.input field={@form[:note]} type="textarea" label="Note" rows="2" />
          </div>

          <:actions>
            <div class="flex flex-wrap gap-2">
              <.link navigate={~p"/manage/jobs/#{@job.id}/materials"}>
                <.button type="button" variant={:outline}>Edit materials</.button>
              </.link>
              <.button
                :if={@events != []}
                type="button"
                phx-click="open_event_materials"
                phx-target={@myself}
                variant={:outline}
              >
                Add materials
              </.button>
              <.button
                :if={@show_arrive}
                type="submit"
                name="action"
                value="arrive"
                variant={:primary}
              >
                Arrive
              </.button>
              <.button
                :if={@show_depart}
                type="submit"
                name="action"
                value="depart"
                variant={:primary}
              >
                Depart
              </.button>
              <.button
                :if={@show_complete}
                type="submit"
                name="action"
                value="complete"
                class="bg-green-50 text-green-700 hover:bg-green-100 shadow-none ring-1 ring-green-200"
              >
                Mark complete
              </.button>
              <.button
                :if={@show_cancel}
                type="submit"
                name="action"
                value="cancel"
                variant={:outline}
              >
                Cancel job
              </.button>
            </div>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{job: job, events: events} = assigns, socket) do
    member = assigns.current_member
    inferred_type = infer_type(events)
    max_odo = max_odometer(events)
    odometer_km = if(max_odo != nil, do: to_string(max_odo), else: "")

    {show_arrive, show_depart, show_complete, show_cancel} =
      button_visibility(job.status, inferred_type)

    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()
      |> String.trim_trailing("Z")

    form =
      AshPhoenix.Form.for_create(Orders.JobEvent, :log,
        as: "event",
        actor: member,
        tenant: member.organisation_id
      )
      |> AshPhoenix.Form.validate(%{
        "data" => %{"type" => to_string(inferred_type), "odometer_km" => odometer_km},
        "timestamp" => now,
        "job_id" => job.id
      })

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       inferred_type: inferred_type,
       odometer_km: odometer_km,
       show_arrive: show_arrive,
       show_depart: show_depart,
       show_complete: show_complete,
       show_cancel: show_cancel,
       form: to_form(form)
     )}
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    odometer_km = params["odometer_km"] || ""
    params = inject_fixed(params, socket)
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, socket |> assign(:form, form) |> assign(:odometer_km, odometer_km)}
  end

  def handle_event("open_event_materials", _params, socket) do
    notify_parent({:manage_event_materials, List.last(socket.assigns.events)})
    {:noreply, socket}
  end

  def handle_event("save", %{"event" => params} = all_params, socket) do
    case Map.get(all_params, "action") do
      a when a in ["arrive", "depart"] ->
        params = inject_fixed(params, socket)

        case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
          {:ok, event} ->
            notify_parent({:event_logged, event})
            {:noreply, socket}

          {:error, form} ->
            {:noreply, assign(socket, :form, form)}
        end

      "complete" ->
        notify_parent({:status_changed, :completed})
        {:noreply, socket}

      "cancel" ->
        notify_parent({:status_changed, :cancelled})
        {:noreply, socket}
    end
  end

  defp inject_fixed(params, socket) do
    data = %{
      "type" => to_string(socket.assigns.inferred_type),
      "odometer_km" => params["odometer_km"] || ""
    }

    params
    |> Map.put("job_id", socket.assigns.job.id)
    |> Map.put("data", data)
    |> Map.delete("odometer_km")
  end

  # Count-based: unmatched arrival means someone is on site → next is departure.
  defp infer_type(events) do
    arrivals = Enum.count(events, fn e -> match?(%Ash.Union{type: :arrival}, e.data) end)
    departures = Enum.count(events, fn e -> match?(%Ash.Union{type: :departure}, e.data) end)
    if arrivals > departures, do: :departure, else: :arrival
  end

  defp max_odometer(events) do
    values =
      Enum.flat_map(events, fn
        %{data: %Ash.Union{type: t, value: v}} when t in [:arrival, :departure] ->
          if v.odometer_km, do: [v.odometer_km], else: []

        _ ->
          []
      end)

    if values == [], do: nil, else: Enum.max(values)
  end

  # :scheduling — no actions; must be placed on calendar first (becomes :scheduled)
  # :scheduled — can arrive or cancel (not yet complete-able)
  # :in_progress, next=departure — on site: can depart, complete, or cancel
  # :in_progress, next=arrival — between pairs: can arrive again, complete, or cancel
  defp button_visibility(:scheduled, :arrival), do: {true, false, false, true}
  defp button_visibility(:in_progress, :departure), do: {false, true, true, true}
  defp button_visibility(:in_progress, :arrival), do: {true, false, true, true}
  defp button_visibility(_, _), do: {false, false, false, false}

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp event_type_label(:arrival), do: "Arrive"
  defp event_type_label(:departure), do: "Depart"
  defp event_type_label(:shift_start), do: "Shift start"
  defp event_type_label(:shift_end), do: "Shift end"
  defp event_type_label(:work_session_start), do: "Work start"
  defp event_type_label(:work_session_stop), do: "Work stop"
  defp event_type_label(other), do: to_string(other)

  defp format_event_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %H:%M")
  end
end
