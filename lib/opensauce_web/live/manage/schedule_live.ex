defmodule OpenSauceWeb.ScheduleLive do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Orders

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Scheduling",
       main_bg: "bg-[#16140E]",
       view: :week,
       offset: 0,
       place_job: nil,
       place_day: nil,
       place_minutes: 420,
       place_duration: 120
     )
     |> load_jobs()}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, view: String.to_existing_atom(view), offset: 0)}
  end

  @impl true
  def handle_event("nav", %{"dir" => "prev"}, socket) do
    {:noreply, assign(socket, :offset, socket.assigns.offset - 1)}
  end

  @impl true
  def handle_event("nav", %{"dir" => "next"}, socket) do
    {:noreply, assign(socket, :offset, socket.assigns.offset + 1)}
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
    {:noreply, assign(socket, place_job: nil)}
  end

  @impl true
  def handle_event("unschedule", _params, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.place_job

    Orders.update_job(
      job,
      %{scheduled_for: nil, start_time: nil, status: :scheduling},
      actor: member,
      tenant: member.organisation_id
    )

    {:noreply, socket |> assign(place_job: nil) |> load_jobs()}
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

    Orders.update_job(
      job,
      %{scheduled_for: date, start_time: start_time, status: new_status, duration_estimate: duration},
      actor: member,
      tenant: member.organisation_id
    )

    {:noreply, socket |> assign(place_job: nil) |> load_jobs()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <% today = Date.utc_today() %>

      <%!-- Header --%>
      <div style="padding:12px 22px 10px;">
        <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;">
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:28px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
            Scheduling
          </h1>
          <div style="display:flex;gap:3px;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:10px;padding:3px;">
            <button
              class={["seg-tab", @view == :week && "seg-tab--on"]}
              style="padding:4px 12px;font-size:12px;"
              type="button"
              phx-click="set_view"
              phx-value-view="week"
            >
              W
            </button>
            <button
              class={["seg-tab", @view == :day && "seg-tab--on"]}
              style="padding:4px 12px;font-size:12px;"
              type="button"
              phx-click="set_view"
              phx-value-view="day"
            >
              D
            </button>
          </div>
        </div>

        <%!-- Period navigation --%>
        <div style="display:flex;align-items:center;gap:8px;margin-top:10px;">
          <button
            type="button"
            phx-click="nav"
            phx-value-dir="prev"
            ontouchstart=""
            style="width:32px;height:32px;display:flex;align-items:center;justify-content:center;border:1.5px solid rgba(52,48,37,0.58);border-radius:8px;background:#211E16;color:#9A9384;cursor:pointer;flex-shrink:0;"
          >
            <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2.2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </button>

          <div style="flex:1;text-align:center;font-size:13.5px;font-weight:600;color:#9A9384;letter-spacing:-0.01em;">
            {if @view == :week, do: week_label(@offset), else: day_label(@offset, today)}
          </div>

          <button
            type="button"
            phx-click="nav"
            phx-value-dir="next"
            ontouchstart=""
            style="width:32px;height:32px;display:flex;align-items:center;justify-content:center;border:1.5px solid rgba(52,48,37,0.58);border-radius:8px;background:#211E16;color:#9A9384;cursor:pointer;flex-shrink:0;"
          >
            <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2.2"
                d="M9 5l7 7-7 7"
              />
            </svg>
          </button>
        </div>
      </div>

      <div style="padding:0 16px 100px;">
        <%!-- Week view --%>
        <div :if={@view == :week}>
          <% days = week_days(@offset) %>
          <div :for={date <- days}>
            <% day_jobs = jobs_for_date(@jobs, date, today) %>
            <div class="dayrow">
              <span
                class="dl"
                style={if date == today, do: "color:#54B57E;", else: ""}
              >
                {Calendar.strftime(date, "%a")}
              </span>
              <span
                class="line"
                style={if date == today, do: "background:rgba(84,181,126,0.35);", else: ""}
              >
              </span>
              <span class="dn">{Calendar.strftime(date, "%-d %b")}</span>
            </div>
            <div :if={day_jobs == []} style="padding:0 2px 10px;">
              <span style="font-size:12.5px;color:#3D3829;">–</span>
            </div>
            <div :if={day_jobs != []} style="display:flex;flex-wrap:wrap;gap:5px;padding-bottom:10px;">
              <.sched_chip :for={job <- day_jobs} job={job} />
            </div>
          </div>
        </div>

        <%!-- Day view --%>
        <div :if={@view == :day}>
          <% target = Date.add(today, @offset) %>
          <% day_jobs = jobs_for_date(@jobs, target, today) %>
          <div
            :if={day_jobs == []}
            style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;"
          >
            Nothing scheduled
          </div>
          <.sched_card :for={job <- day_jobs} job={job} open_drawer />
        </div>

        <%!-- Unscheduled --%>
        <% unsched = unscheduled_jobs(@jobs) %>
        <div style="margin-top:20px;">
          <div style="display:flex;align-items:center;gap:10px;padding:8px 2px 10px;">
            <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Unscheduled{if unsched != [], do: " · #{length(unsched)}", else: ""}
            </span>
            <div style="flex:1;height:1px;background:rgba(52,48,37,0.58);">
            </div>
          </div>
          <div
            :if={unsched == []}
            style="text-align:center;color:#6E675A;font-size:13px;font-weight:500;padding:4px 0 16px;"
          >
            None
          </div>
          <.sched_card :for={job <- unsched} job={job} show_due />
        </div>
      </div>

      <%!-- Place sheet --%>
      <div
        :if={@place_job}
        class="fixed inset-0 z-[60] flex items-end justify-center"
        role="dialog"
        aria-label="Place job"
      >
        <div class="absolute inset-0 bg-black/50" phx-click="place_close" aria-hidden="true" />
        <div
          class="relative w-full max-w-lg bg-[#211E16] rounded-t-2xl px-5 pt-4 space-y-5"
          style="border-top:1.5px solid rgba(52,48,37,0.58);padding-bottom:max(2rem,env(safe-area-inset-bottom))"
        >
          <%!-- handle --%>
          <div style="width:36px;height:4px;background:rgba(52,48,37,0.7);border-radius:2px;margin:0 auto;"></div>

          <%!-- title + close --%>
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
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <%!-- day chips --%>
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

          <%!-- start time slider --%>
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

          <%!-- duration slider --%>
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

          <%!-- confirm --%>
          <.leaf_button phx-click="place_confirm">
            {Calendar.strftime(@place_day, "%a %-d %b")} · {format_minutes(@place_minutes)}
          </.leaf_button>

          <%!-- unschedule --%>
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

  attr :job, :any, required: true

  defp sched_chip(assigns) do
    ~H"""
    <div
      phx-click="place_open"
      phx-value-id={@job.id}
      ontouchstart=""
      style={
        "flex:0 0 calc(25% - 4px);min-width:0;padding:7px 8px;border-radius:8px;cursor:pointer;overflow:hidden;" <>
          if @job.status == :in_progress,
            do: "background:#211E16;border:1.5px solid #54B57E;",
            else: "background:#211E16;border:1.5px solid rgba(52,48,37,0.58);"
      }
    >
      <div style="font-size:10px;font-weight:700;color:#54B57E;letter-spacing:0.02em;line-height:1;margin-bottom:3px;">
        {if @job.start_time, do: Calendar.strftime(@job.start_time, "%H:%M"), else: "·"}
      </div>
      <div style="font-size:12px;font-weight:700;color:#F4EFE2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.2;">
        {chip_who(@job)}
      </div>
      <div
        :if={chip_where(@job)}
        style="font-size:10.5px;color:#9A9384;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.2;margin-top:1px;"
      >
        {chip_where(@job)}
      </div>
    </div>
    """
  end

  attr :job, :any, required: true
  attr :show_due, :boolean, default: false
  attr :open_drawer, :boolean, default: false

  defp sched_card(assigns) do
    ~H"""
    <div
      class={["jcard", @job.status == :in_progress && "live"]}
      phx-click={
        if @open_drawer,
          do: "place_open",
          else: if(@job.status != :scheduling, do: JS.navigate(~p"/manage/jobs/#{@job.id}"))
      }
      phx-value-id={@job.id}
      ontouchstart=""
    >
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
        <div style="min-width:0;flex:1;">
          <div style="font-size:15.5px;font-weight:700;letter-spacing:-0.01em;line-height:1.25;color:#F4EFE2;">
            {job_who(@job)}
          </div>
          <div
            :if={job_where_text(@job)}
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
            {job_where_text(@job)}
          </div>
        </div>
        <span :if={@job.status == :in_progress} class="pill live">
          <span class="dot pulse"></span>On site
        </span>
        <span :if={@job.status == :scheduled} class="pill sched">
          <span class="dot"></span>Sched
        </span>
        <button
          :if={@job.status == :scheduling}
          class="pill cancel"
          type="button"
          ontouchstart=""
          style="border:none;cursor:pointer;"
          phx-click="place_open"
          phx-value-id={@job.id}
        >
          Place
        </button>
      </div>

      <div style="margin-top:11px;display:flex;align-items:center;justify-content:space-between;gap:8px;">
        <div style="display:flex;align-items:center;gap:6px;min-width:0;flex:1;">
          <span
            :if={@job.start_time}
            style="font-size:11px;font-weight:700;color:#6E675A;background:#16140E;border:1px solid rgba(52,48,37,0.5);border-radius:6px;padding:2px 6px;flex-shrink:0;letter-spacing:0.02em;"
          >
            {Calendar.strftime(@job.start_time, "%H:%M")}
          </span>
          <span :if={@job.service_category} class="jcat">
            <span class="catdot" style={"background:#{category_color(@job.service_category)}"}></span>
            {service_category_label(@job.service_category)}
          </span>
          <span :if={!@job.service_category} class="jcat" style="color:#6E675A;">—</span>
        </div>
        <span
          :if={@show_due && @job.due_by}
          style="font-size:11.5px;color:#6E675A;font-weight:600;flex-shrink:0;"
        >
          due {Calendar.strftime(@job.due_by, "%-d %b")}
        </span>
      </div>
    </div>
    """
  end

  defp load_jobs(socket) do
    member = socket.assigns.current_member

    jobs =
      Orders.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer]]
      )

    assign(socket, :jobs, jobs)
  end

  defp week_days(offset) do
    today = Date.utc_today()
    dow = Date.day_of_week(today)
    monday = Date.add(today, -(dow - 1))
    week_start = Date.add(monday, offset * 7)
    Enum.map(0..6, &Date.add(week_start, &1))
  end

  defp week_label(offset) do
    today = Date.utc_today()
    dow = Date.day_of_week(today)
    monday = Date.add(today, -(dow - 1))
    week_start = Date.add(monday, offset * 7)
    week_end = Date.add(week_start, 6)

    start_str =
      if week_start.month == week_end.month,
        do: Calendar.strftime(week_start, "%-d"),
        else: Calendar.strftime(week_start, "%-d %b")

    "#{start_str}–#{Calendar.strftime(week_end, "%-d %b")}"
  end

  defp day_label(0, today), do: "Today · #{Calendar.strftime(today, "%-d %b")}"
  defp day_label(1, today), do: "Tomorrow · #{Calendar.strftime(Date.add(today, 1), "%-d %b")}"

  defp day_label(-1, today),
    do: "Yesterday · #{Calendar.strftime(Date.add(today, -1), "%-d %b")}"

  defp day_label(offset, today),
    do: Calendar.strftime(Date.add(today, offset), "%A · %-d %b")

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

  defp chip_who(job) do
    cl = customer_label(job)
    if cl == "", do: (job.garden && job.garden.name) || "Job", else: cl
  end

  defp chip_where(job) do
    cl = customer_label(job)
    if cl != "" && job.garden && job.garden.name, do: job.garden.name, else: nil
  end

  defp job_who(job) do
    cl = customer_label(job)
    if cl == "", do: (job.garden && (job.garden.name || "Unnamed site")) || "Unnamed job", else: cl
  end

  defp job_where_text(%{garden: nil}), do: nil

  defp job_where_text(%{garden: g}) do
    parts = [g.name, g.zip] |> Enum.reject(&is_nil/1) |> Enum.reject(&(&1 == ""))
    if parts == [], do: nil, else: Enum.join(parts, " · ")
  end

  defp customer_label(%{engagement: nil}), do: ""
  defp customer_label(%{engagement: %{customer: nil}}), do: ""

  defp customer_label(%{engagement: %{customer: c}}) do
    if c.company_name_nickname,
      do: c.company_name_nickname,
      else: "#{c.first_name} #{c.last_name}"
  end

  defp category_color(:installation), do: "#DB9258"
  defp category_color(:delivery), do: "#DB9258"
  defp category_color(:consultation), do: "#5AB4D8"
  defp category_color(:design), do: "#5AB4D8"
  defp category_color(_), do: "#54B57E"

  defp service_category_label(nil), do: "—"
  defp service_category_label(:installation), do: "Installation"
  defp service_category_label(:delivery), do: "Delivery"
  defp service_category_label(:pruning), do: "Pruning"
  defp service_category_label(:consultation), do: "Consultation"
  defp service_category_label(:design), do: "Design"
  defp service_category_label(:opening), do: "Opening"
  defp service_category_label(:winterization), do: "Winterization"
  defp service_category_label(:maintenance), do: "Maintenance"
  defp service_category_label(other), do: to_string(other)
end
