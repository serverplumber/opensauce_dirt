defmodule OpenSauceWeb.TodayLive do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Work

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Home",
       main_bg: "bg-[#16140E]",
       offset: 0,
       search: "",
       place_job: nil,
       place_day: nil,
       place_minutes: 420,
       place_duration: 120
     )
     |> load_jobs()
     |> load_engagements()}
  end

  @impl true
  def handle_params(%{"place_job_id" => job_id}, _url, socket) do
    today = Date.utc_today()
    job = Enum.find(socket.assigns.jobs, &(&1.id == job_id))

    if job do
      place_day = job.scheduled_for || today

      place_minutes =
        if job.start_time,
          do: job.start_time.hour * 60 + job.start_time.minute,
          else: next_available_minutes(socket.assigns.jobs, place_day)

      {:noreply,
       assign(socket,
         place_job: job,
         place_day: place_day,
         place_minutes: place_minutes,
         place_duration: job.duration_estimate || 120
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("nav", %{"dir" => "prev"}, socket) do
    {:noreply, assign(socket, :offset, socket.assigns.offset - 1)}
  end

  @impl true
  def handle_event("nav", %{"dir" => "next"}, socket) do
    {:noreply, assign(socket, :offset, socket.assigns.offset + 1)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, :search, q)}
  end

  @impl true
  def handle_event("place_open", %{"id" => job_id}, socket) do
    job = Enum.find(socket.assigns.jobs, &(&1.id == job_id))
    today = Date.utc_today()

    place_day = job.scheduled_for || today

    place_minutes =
      if job.start_time do
        job.start_time.hour * 60 + job.start_time.minute
      else
        next_available_minutes(socket.assigns.jobs, place_day)
      end

    duration = job.duration_estimate || 120
    {:noreply, assign(socket, place_job: job, place_day: place_day, place_minutes: place_minutes, place_duration: duration)}
  end

  @impl true
  def handle_event("place_close", _params, socket) do
    {:noreply, socket |> assign(place_job: nil) |> push_patch(to: ~p"/manage/today")}
  end

  @impl true
  def handle_event("unschedule", _params, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.place_job

    Work.update_job(
      job,
      %{scheduled_for: nil, start_time: nil, status: :scheduling},
      actor: member,
      tenant: member.organisation_id
    )

    {:noreply, socket |> assign(place_job: nil) |> load_jobs() |> push_patch(to: ~p"/manage/today")}
  end

  @impl true
  def handle_event("place_day", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)
    start_min = next_available_minutes(socket.assigns.jobs, date)
    {:noreply, assign(socket, place_day: date, place_minutes: start_min)}
  end

  @impl true
  def handle_event("place_time", %{"value" => value}, socket) do
    {:noreply, assign(socket, place_minutes: String.to_integer(value))}
  end

  @impl true
  def handle_event("place_duration", %{"value" => value}, socket) do
    {:noreply, assign(socket, place_duration: String.to_integer(value))}
  end

  @impl true
  def handle_event("place_confirm", _params, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.place_job
    date = socket.assigns.place_day
    minutes = socket.assigns.place_minutes
    duration = socket.assigns.place_duration
    start_time = Time.new!(div(minutes, 60), rem(minutes, 60), 0)
    new_status = if job.status == :scheduling, do: :scheduled, else: job.status

    Work.update_job(
      job,
      %{scheduled_for: date, start_time: start_time, status: new_status, duration_estimate: duration},
      actor: member,
      tenant: member.organisation_id
    )

    {:noreply, socket |> assign(place_job: nil) |> load_jobs()}
  end

  @impl true
  def handle_event("fab_stop_shift", _params, socket) do
    member = socket.assigns.current_member
    shift = socket.assigns.active_shift
    now = DateTime.truncate(DateTime.utc_now(), :second)
    opts = [actor: member, tenant: member.organisation_id]

    Work.log_job_event!(
      %{job_id: shift.id, timestamp: now, data: %{type: :shift_end, odometer_km: nil}, organisation_id: member.organisation_id},
      opts
    )

    Work.complete_job(shift, opts)

    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_event("fab_manager_action", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manage/jobs/adhoc")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <% today = Date.utc_today() %>
      <% target = Date.add(today, @offset) %>

      <%!-- Header --%>
      <div style="padding:14px 16px 10px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0 0 10px;">
          Home
        </h1>

        <%!-- Search --%>
        <form phx-change="search" style="position:relative;margin-bottom:14px;">
          <div style="position:absolute;left:12px;top:50%;transform:translateY(-50%);color:#6E675A;line-height:0;pointer-events:none;">
            <svg width="15" height="15" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <circle cx="11" cy="11" r="8" stroke-width="2" />
              <path d="M21 21l-4.35-4.35" stroke-width="2" stroke-linecap="round" />
            </svg>
          </div>
          <input
            type="search"
            name="q"
            value={@search}
            placeholder="Search plants…"
            autocomplete="off"
            style="width:100%;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 14px 10px 38px;color:#F4EFE2;font-size:14px;outline:none;box-sizing:border-box;-webkit-appearance:none;"
          />
        </form>

        <%!-- Day navigation --%>
        <div style="display:flex;align-items:center;gap:8px;">
          <button
            type="button"
            phx-click="nav"
            phx-value-dir="prev"
            ontouchstart=""
            style="width:32px;height:32px;display:flex;align-items:center;justify-content:center;border:1.5px solid rgba(52,48,37,0.58);border-radius:8px;background:#211E16;color:#9A9384;cursor:pointer;flex-shrink:0;"
          >
            <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <div style="flex:1;text-align:center;font-size:13.5px;font-weight:600;color:#9A9384;letter-spacing:-0.01em;">
            {day_label(@offset, today)}
          </div>
          <button
            type="button"
            phx-click="nav"
            phx-value-dir="next"
            ontouchstart=""
            style="width:32px;height:32px;display:flex;align-items:center;justify-content:center;border:1.5px solid rgba(52,48,37,0.58);border-radius:8px;background:#211E16;color:#9A9384;cursor:pointer;flex-shrink:0;"
          >
            <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>

      <%!-- Day schedule --%>
      <div style="padding:0 16px 100px;">
        <% day_jobs = jobs_for_date(@jobs, target, today) %>
        <div
          :if={day_jobs == []}
          style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;"
        >
          Nothing scheduled
        </div>
        <.job_card :for={job <- day_jobs} job={job} return_to="/manage/today" on_place="place_open" />

        <%!-- Unscheduled --%>
        <% unsched = unscheduled_jobs(@jobs) %>
        <div style="margin-top:20px;">
          <div style="display:flex;align-items:center;gap:10px;padding:8px 2px 10px;">
            <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Unscheduled{if unsched != [], do: " · #{length(unsched)}", else: ""}
            </span>
            <div style="flex:1;height:1px;background:rgba(52,48,37,0.58);"></div>
          </div>
          <div
            :if={unsched == []}
            style="text-align:center;color:#6E675A;font-size:13px;font-weight:500;padding:4px 0 16px;"
          >
            None
          </div>
          <.job_card :for={job <- unsched} job={job} return_to="/manage/today" on_place="place_open" show_due />
        </div>

        <%!-- Engagements --%>
        <div style="margin-top:20px;">
          <div style="display:flex;align-items:center;gap:10px;padding:8px 2px 10px;">
            <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Engagements{if @engagements != [], do: " · #{length(@engagements)}", else: ""}
            </span>
            <div style="flex:1;height:1px;background:rgba(52,48,37,0.58);"></div>
          </div>
          <div
            :if={@engagements == []}
            style="text-align:center;color:#6E675A;font-size:13px;font-weight:500;padding:4px 0 16px;"
          >
            None
          </div>
          <.eng_card :for={e <- @engagements} engagement={e} />
        </div>
      </div>

      <%!-- Action FAB --%>
      <% is_manager = @current_member.role in [:manager, :owner] %>
      <%!-- No active shift: green go for everyone --%>
      <button
        :if={is_nil(@active_shift)}
        class="fab"
        type="button"
        ontouchstart=""
        phx-click={JS.navigate(~p"/manage/shifts/start")}
        title="Start shift"
      >
        <svg width="26" height="26" viewBox="0 0 24 24" fill="#0C1F15">
          <path d="M8 5.5l11 6.5-11 6.5V5.5z" />
        </svg>
      </button>
      <%!-- Shift active, staff: red stop --%>
      <button
        :if={@active_shift && !is_manager}
        class="fab fab--stop"
        type="button"
        ontouchstart=""
        phx-click="fab_stop_shift"
        title="End shift"
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="#0C1F15">
          <rect x="5" y="5" width="14" height="14" rx="2" />
        </svg>
      </button>
      <%!-- Shift active, manager: green + for ad hoc job --%>
      <button
        :if={@active_shift && is_manager}
        class="fab"
        type="button"
        ontouchstart=""
        phx-click="fab_manager_action"
        title="New job"
      >
        <.add_job_icon />
      </button>

      <%!-- Place sheet --%>
      <div
        :if={@place_job}
        class="fixed inset-0 z-[60] flex items-end justify-center"
        role="dialog"
        aria-label="Schedule"
      >
        <div class="absolute inset-0 bg-black/50" phx-click="place_close" aria-hidden="true" />
        <div
          class="relative w-full max-w-lg bg-[#211E16] rounded-t-2xl px-5 pt-4 space-y-5"
          style="border-top:1.5px solid rgba(52,48,37,0.58);padding-bottom:max(2rem,env(safe-area-inset-bottom))"
        >
          <div style="width:36px;height:4px;background:rgba(52,48,37,0.7);border-radius:2px;margin:0 auto;"></div>

          <div style="display:flex;align-items:center;justify-content:space-between;">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;margin:0;">
              Schedule
            </p>
            <button
              type="button"
              phx-click="place_close"
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div style="display:flex;gap:5px;">
            <button
              :for={day <- Enum.map(0..6, &Date.add(today, &1))}
              type="button"
              phx-click="place_day"
              phx-value-date={Date.to_iso8601(day)}
              ontouchstart=""
              style={
                "flex:1;min-width:0;padding:8px 2px;border-radius:10px;border:1.5px solid;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:1px;" <>
                  if(day == @place_day,
                    do: "background:rgba(84,181,126,0.15);border-color:#54B57E;color:#54B57E;",
                    else: "background:#16140E;border-color:rgba(52,48,37,0.58);color:#6E675A;"
                  )
              }
            >
              <span style="font-size:9px;font-weight:700;letter-spacing:0.05em;text-transform:uppercase;">
                {Calendar.strftime(day, "%a")}
              </span>
              <span style="font-size:15px;font-weight:700;line-height:1.15;">
                {Calendar.strftime(day, "%-d")}
              </span>
            </button>
          </div>

          <div>
            <div style="display:flex;align-items:baseline;justify-content:space-between;margin-bottom:6px;">
              <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
                {if placed_on_day?(@jobs, @place_day), do: "Next", else: "Start"}
              </span>
              <span style="font-size:24px;font-weight:700;color:#F4EFE2;letter-spacing:-0.03em;font-family:'Bricolage Grotesque',sans-serif;">
                {format_minutes(@place_minutes)}
              </span>
            </div>
            <form phx-change="place_time">
              <input
                type="range"
                name="value"
                min="420"
                max="1140"
                step="15"
                value={@place_minutes}
                style="width:100%;accent-color:#54B57E;cursor:pointer;"
              />
            </form>
          </div>

          <div>
            <div style="display:flex;align-items:baseline;justify-content:space-between;margin-bottom:6px;">
              <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
                Duration
              </span>
              <span style="font-size:24px;font-weight:700;color:#F4EFE2;letter-spacing:-0.03em;font-family:'Bricolage Grotesque',sans-serif;">
                {format_duration(@place_duration * 60)}
              </span>
            </div>
            <form phx-change="place_duration">
              <input
                type="range"
                name="value"
                min="15"
                max="480"
                step="15"
                value={@place_duration}
                style="width:100%;accent-color:#54B57E;cursor:pointer;"
              />
            </form>
          </div>

          <.leaf_button phx-click="place_confirm">
            {Calendar.strftime(@place_day, "%a %-d %b")} · {format_minutes(@place_minutes)}
          </.leaf_button>

          <button
            :if={@place_job.scheduled_for != nil}
            type="button"
            phx-click="unschedule"
            ontouchstart=""
            style="width:100%;padding:10px;background:none;border:none;color:#6E675A;font-size:13px;font-weight:600;cursor:pointer;letter-spacing:-0.01em;"
          >
            Remove from schedule
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp load_jobs(socket) do
    member = socket.assigns.current_member

    jobs =
      Work.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer]]
      )

    active_shift = Enum.find(jobs, &(&1.type == :shift && &1.status == :in_progress))

    socket
    |> assign(:jobs, Enum.reject(jobs, &(&1.type == :shift)))
    |> assign(:active_shift, active_shift)
  end

  defp load_engagements(socket) do
    member = socket.assigns.current_member

    engagements =
      CRM.list_engagements!(
        actor: member,
        tenant: member.organisation_id,
        load: [:customer, :garden]
      )
      |> Enum.reject(&(&1.status in [:completed, :cancelled]))
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    assign(socket, :engagements, engagements)
  end

  defp day_label(0, today), do: "Today · #{Calendar.strftime(today, "%-d %b")}"
  defp day_label(1, today), do: "Tomorrow · #{Calendar.strftime(Date.add(today, 1), "%-d %b")}"
  defp day_label(-1, today), do: "Yesterday · #{Calendar.strftime(Date.add(today, -1), "%-d %b")}"
  defp day_label(offset, today), do: Calendar.strftime(Date.add(today, offset), "%A · %-d %b")

  defp jobs_for_date(jobs, date, today) do
    jobs
    |> Enum.filter(fn j ->
      cond do
        j.status == :in_progress -> date == today
        j.status == :scheduled -> j.scheduled_for == date
        true -> false
      end
    end)
    |> Enum.sort_by(fn j ->
      case j.start_time do
        nil -> {1, 0}
        t -> {0, t.hour * 60 + t.minute}
      end
    end)
  end

  defp unscheduled_jobs(jobs) do
    jobs
    |> Enum.filter(&(&1.status == :scheduling))
    |> Enum.sort_by(fn j ->
      case j.due_by do
        nil -> {1, ~D[9999-12-31]}
        date -> {0, date}
      end
    end)
  end

  defp placed_on_day?(jobs, date) do
    Enum.any?(jobs, fn j ->
      j.status in [:scheduled, :in_progress] and j.scheduled_for == date and
        not is_nil(j.start_time)
    end)
  end

  defp next_available_minutes(jobs, date) do
    placed =
      Enum.filter(jobs, fn j ->
        j.status in [:scheduled, :in_progress] and j.scheduled_for == date and
          not is_nil(j.start_time)
      end)

    case placed do
      [] ->
        420

      _ ->
        placed
        |> Enum.map(fn j ->
          j.start_time.hour * 60 + j.start_time.minute + (j.duration_estimate || 0)
        end)
        |> Enum.max()
        |> min(1140)
    end
  end

  defp format_minutes(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    "#{String.pad_leading(to_string(h), 2, "0")}:#{String.pad_leading(to_string(m), 2, "0")}"
  end

  attr :engagement, :any, required: true

  defp eng_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/manage/customers/#{@engagement.customer.reference}/engagements/#{@engagement.id}?return_to=/manage/today"}
      style="display:block;text-decoration:none;"
    >
      <div class="jcard">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
          <div style="min-width:0;flex:1;">
            <div style="font-size:15.5px;font-weight:700;letter-spacing:-0.01em;line-height:1.25;color:#F4EFE2;">
              {eng_customer_name(@engagement)}
            </div>
            <div
              :if={@engagement.garden && @engagement.garden.name}
              style="margin-top:4px;font-size:12.5px;color:#9A9384;line-height:1.3;display:flex;align-items:center;gap:5px;"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style="flex:0 0 auto;">
                <path
                  d="M12 21s7-5.5 7-11a7 7 0 1 0-14 0c0 5.5 7 11 7 11Z"
                  stroke="#9A9384"
                  stroke-width="1.6"
                />
                <circle cx="12" cy="10" r="2.4" stroke="#9A9384" stroke-width="1.6" />
              </svg>
              {@engagement.garden.name}
            </div>
          </div>
          <span style={"font-size:11px;font-weight:700;padding:3px 8px;border-radius:999px;flex-shrink:0;background:#{eng_status_bg(@engagement.status)};color:#{eng_status_color(@engagement.status)};"}>
            {eng_status_label(@engagement.status)}
          </span>
        </div>
        <div
          :if={@engagement.scope_title}
          style="margin-top:8px;font-size:12.5px;color:#9A9384;line-height:1.35;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"
        >
          {@engagement.scope_title}
        </div>
        <div
          :if={!@engagement.scope_title}
          style="margin-top:8px;font-size:12.5px;color:#6E675A;"
        >
          No title
        </div>
      </div>
    </.link>
    """
  end

  defp eng_customer_name(%{customer: %{company_name_nickname: nick}}) when not is_nil(nick), do: nick
  defp eng_customer_name(%{customer: %{first_name: f, last_name: l}}), do: "#{f} #{l}"
  defp eng_customer_name(_), do: "Unknown client"

  defp eng_status_label(:draft), do: "Draft"
  defp eng_status_label(:proposed), do: "Proposed"
  defp eng_status_label(:signed), do: "Signed"
  defp eng_status_label(:in_progress), do: "Active"
  defp eng_status_label(:completed), do: "Complete"
  defp eng_status_label(:cancelled), do: "Cancelled"
  defp eng_status_label(other), do: to_string(other)

  defp eng_status_color(:draft), do: "#9A9384"
  defp eng_status_color(:proposed), do: "#DB9258"
  defp eng_status_color(:signed), do: "#5AB4D8"
  defp eng_status_color(:in_progress), do: "#54B57E"
  defp eng_status_color(_), do: "#6E675A"

  defp eng_status_bg(:draft), do: "rgba(154,147,132,0.12)"
  defp eng_status_bg(:proposed), do: "rgba(219,146,88,0.12)"
  defp eng_status_bg(:signed), do: "rgba(90,180,216,0.12)"
  defp eng_status_bg(:in_progress), do: "rgba(84,181,126,0.12)"
  defp eng_status_bg(_), do: "rgba(110,103,90,0.12)"

end
