defmodule OpenSauceWeb.JobLive.EventLogComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Work

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        :if={@events != []}
        style="margin-bottom:16px;border-bottom:1px solid rgba(52,48,37,0.58);padding-bottom:4px;"
      >
        <div
          :for={event <- @events}
          style="display:flex;align-items:center;gap:10px;padding:7px 0;border-bottom:1px solid rgba(52,48,37,0.18);"
        >
          <span style="font-size:13px;font-weight:600;color:#F4EFE2;flex-shrink:0;">
            {event_type_label(event.data.type)}
          </span>
          <span style="font-size:11px;color:#9A9384;flex-shrink:0;">
            {format_event_time(event.timestamp)}
          </span>
          <span
            :if={event.note}
            style="font-size:11px;color:#6E675A;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"
          >
            {event.note}
          </span>
        </div>
      </div>

      <.form
        for={@form}
        id={"event-log-form-#{@job.id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:14px;"
      >
        <div style="display:flex;gap:12px;">
          <div style="flex:1;">
            <p class="dark-label">Time</p>
            <input
              type="datetime-local"
              id={@form[:timestamp].id}
              name={@form[:timestamp].name}
              value={Phoenix.HTML.Form.normalize_value("datetime-local", @form[:timestamp].value)}
              step="1800"
              class="dark-input"
              style="width:100%;"
            />
          </div>
          <div style="width:118px;">
            <p class="dark-label">Odometer (km)</p>
            <input
              type="number"
              name="event[odometer_km]"
              value={@odometer_km}
              min="0"
              step="1"
              class="dark-input"
              style="width:100%;"
            />
          </div>
        </div>

        <div>
          <p class="dark-label">Note</p>
          <textarea
            id={@form[:note].id}
            name={@form[:note].name}
            rows="2"
            class="dark-textarea"
            phx-debounce="blur"
          >{Phoenix.HTML.Form.normalize_value("textarea", @form[:note].value)}</textarea>
        </div>

        <div style="display:flex;flex-wrap:wrap;gap:8px;padding-top:4px;">
          <.link :if={@events != []} navigate={~p"/manage/jobs/#{@job.id}/materials"}>
            <button
              type="button"
              ontouchstart=""
              style="background:none;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 16px;font-size:13px;font-weight:600;color:#9A9384;cursor:pointer;"
            >
              Edit materials
            </button>
          </.link>
          <button
            :if={@events != []}
            type="button"
            phx-click="open_event_materials"
            phx-target={@myself}
            ontouchstart=""
            style="background:none;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 16px;font-size:13px;font-weight:600;color:#9A9384;cursor:pointer;"
          >
            Add materials
          </button>
          <button
            :if={@show_arrive}
            type="submit"
            name="action"
            value="arrive"
            ontouchstart=""
            style="background:#54B57E;border:none;border-radius:12px;padding:11px 20px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
          >
            Arrive
          </button>
          <button
            :if={@show_depart}
            type="submit"
            name="action"
            value="depart"
            ontouchstart=""
            style="background:#54B57E;border:none;border-radius:12px;padding:11px 20px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
          >
            Depart
          </button>
          <button
            :if={@show_complete}
            type="submit"
            name="action"
            value="complete"
            ontouchstart=""
            style="background:rgba(84,181,126,0.15);border:1px solid rgba(84,181,126,0.3);border-radius:12px;padding:10px 16px;font-size:13px;font-weight:600;color:#54B57E;cursor:pointer;"
          >
            Mark complete
          </button>
          <button
            :if={@show_cancel}
            type="submit"
            name="action"
            value="cancel"
            ontouchstart=""
            style="background:none;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 16px;font-size:13px;font-weight:600;color:#9A9384;cursor:pointer;"
          >
            Cancel job
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{job: job, events: events} = assigns, socket) do
    member = assigns.current_member
    inferred_type = infer_type(events)
    max_odo = max_odometer(events)
    odometer_km = if(max_odo == nil, do: "", else: to_string(max_odo))

    {show_arrive, show_depart, show_complete, show_cancel} =
      button_visibility(job.status, inferred_type)

    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()
      |> String.trim_trailing("Z")

    form =
      Work.JobEvent
      |> AshPhoenix.Form.for_create(:log,
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
