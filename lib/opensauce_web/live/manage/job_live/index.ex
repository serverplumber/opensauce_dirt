defmodule OpenSauceWeb.JobLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Orders
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- page header --%>
      <div style="padding:12px 22px 14px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:28px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
          Jobs
        </h1>

        <%!-- segmented control --%>
        <div style="margin-top:14px;display:flex;gap:4px;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:13px;padding:4px;">
          <button class={["seg-tab", @tab == :today && "seg-tab--on"]} type="button" phx-click="set_tab" phx-value-tab="today">
            Today
            <span :if={@counts.today > 0} style="font-size:11px;font-weight:700;opacity:0.7;">{@counts.today}</span>
          </button>
          <button class={["seg-tab", @tab == :upcoming && "seg-tab--on"]} type="button" phx-click="set_tab" phx-value-tab="upcoming">
            Upcoming
            <span :if={@counts.upcoming > 0} style="font-size:11px;font-weight:700;opacity:0.7;">{@counts.upcoming}</span>
          </button>
          <button class={["seg-tab", @tab == :done && "seg-tab--on"]} type="button" phx-click="set_tab" phx-value-tab="done">
            Done
          </button>
        </div>
      </div>

      <%!-- job list --%>
      <% today = Date.utc_today() %>
      <div style="padding:4px 16px 100px;">
        <%!-- today tab: single group --%>
        <div :if={@tab == :today}>
          <div :if={@counts.today > 0}>
            <div class="dayrow">
              <span class="dl">Today</span>
              <span class="line"></span>
              <span class="dn">{day_date_label(today, today)}</span>
            </div>
            <.job_card :for={job <- jobs_for_tab(@jobs, :today, today)} job={job} />
          </div>
          <div :if={@counts.today == 0} style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;">
            Nothing scheduled for today
          </div>
        </div>

        <%!-- upcoming tab: grouped by date --%>
        <div :if={@tab == :upcoming}>
          <div :if={@counts.upcoming > 0}>
            <div :for={{date, date_jobs} <- group_by_date(jobs_for_tab(@jobs, :upcoming, today))}>
              <div class="dayrow">
                <span class="dl">{day_group_label(date, today)}</span>
                <span class="line"></span>
                <span class="dn">{day_date_label(date, today)}</span>
              </div>
              <.job_card :for={job <- date_jobs} job={job} />
            </div>
          </div>
          <div :if={@counts.upcoming == 0} style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;">
            Nothing upcoming
          </div>
        </div>

        <%!-- done tab: flat list --%>
        <div :if={@tab == :done}>
          <div :if={@counts.done > 0}>
            <.job_card :for={job <- jobs_for_tab(@jobs, :done, today)} job={job} />
          </div>
          <div :if={@counts.done == 0} style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;">
            No completed jobs yet
          </div>
        </div>
      </div>

    </div>

    <%!-- floating action button --%>
    <button class="fab" type="button" phx-click={JS.patch(~p"/manage/jobs/new")} ontouchstart="" title="New job">
      <svg width="26" height="26" viewBox="0 0 24 24" fill="none">
        <path d="M12 5v14M5 12h14" stroke="#0C1F15" stroke-width="2.4" stroke-linecap="round"/>
      </svg>
    </button>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="job-modal"
      title={@page_title}
      show
      on_cancel={JS.patch(~p"/manage/jobs")}
    >
      <.live_component
        module={OpenSauceWeb.JobLive.FormComponent}
        id={(@job && @job.id) || :new}
        job={@job}
        current_member={@current_member}
        patch={~p"/manage/jobs"}
      />
    </.modal>

    <.modal
      :if={@materials_job_id != nil}
      id="job-materials-modal"
      title="Materials"
      max_width="max-w-2xl"
      show
      on_cancel={JS.push("close_materials")}
    >
      <.live_component
        module={OpenSauceWeb.JobLive.MaterialsComponent}
        id={"job-materials-#{@materials_job_id}"}
        job_id={@materials_job_id}
        current_member={@current_member}
        currency={@organisation.currency}
      />
    </.modal>

    <.modal
      :if={@event_log_job != nil}
      id="event-log-modal"
      title={"Log event — #{event_log_title(@event_log_job)}"}
      show
      on_cancel={JS.push("close_event_log")}
    >
      <.live_component
        module={OpenSauceWeb.JobLive.EventLogComponent}
        id={"event-log-#{@event_log_job.id}"}
        job={@event_log_job}
        events={@event_log_events}
        current_member={@current_member}
      />
    </.modal>

    <.modal
      :if={@event_materials_event != nil}
      id="event-materials-modal"
      title="Event materials"
      max_width="max-w-2xl"
      show
      on_cancel={JS.push("close_event_materials")}
    >
      <.live_component
        module={OpenSauceWeb.JobLive.EventMaterialsComponent}
        id={"event-materials-#{@event_materials_event.id}"}
        job_event={@event_materials_event}
        current_member={@current_member}
        currency={@organisation.currency}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       tab: :today,
       materials_job_id: nil,
       event_log_job: nil,
       event_log_events: [],
       event_materials_event: nil
     )
     |> load_jobs()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Jobs")
    |> assign(:main_bg, "bg-[#16140E]")
    |> assign(:job, nil)
    |> then(&Navigation.assign(&1, :jobs, [Navigation.root(:jobs)]))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Job")
    |> assign(:job, nil)
    |> then(&Navigation.assign(&1, :jobs, [Navigation.root(:jobs), Navigation.page(:jobs, :new_job)]))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    member = socket.assigns.current_member

    job =
      Orders.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer]]
      )

    socket
    |> assign(:page_title, "Edit Job")
    |> assign(:job, job)
    |> then(&Navigation.assign(&1, :jobs, [Navigation.root(:jobs)]))
  end

  @impl true
  def handle_info({OpenSauceWeb.JobLive.FormComponent, {:saved, _job}}, socket) do
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_info({OpenSauceWeb.JobLive.EventLogComponent, {:manage_event_materials, event}}, socket) do
    {:noreply,
     socket
     |> assign(event_log_job: nil, event_log_events: [])
     |> assign(event_materials_event: event)}
  end

  @impl true
  def handle_info({OpenSauceWeb.JobLive.EventLogComponent, {:event_logged, event}}, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.event_log_job

    if event.data.type == :arrival && job.status == :scheduled do
      Orders.mark_job_in_progress(job, actor: member, tenant: member.organisation_id)
    end

    {:noreply, socket |> assign(event_log_job: nil, event_log_events: []) |> load_jobs()}
  end

  @impl true
  def handle_info({OpenSauceWeb.JobLive.EventLogComponent, {:status_changed, status}}, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.event_log_job
    opts = [actor: member, tenant: member.organisation_id]

    case status do
      :completed -> Orders.complete_job(job, opts)
      :cancelled -> Orders.cancel_job(job, opts)
    end

    {:noreply, socket |> assign(event_log_job: nil, event_log_events: []) |> load_jobs()}
  end

  @impl true
  def handle_event("open_materials", %{"id" => id}, socket) do
    {:noreply, assign(socket, :materials_job_id, id)}
  end

  @impl true
  def handle_event("close_materials", _params, socket) do
    {:noreply, assign(socket, :materials_job_id, nil)}
  end

  @impl true
  def handle_event("open_event_log", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    job = Enum.find(socket.assigns.jobs, &(&1.id == id))

    events =
      Orders.list_job_events!(job.id,
        actor: member,
        tenant: member.organisation_id
      )

    {:noreply, assign(socket, event_log_job: job, event_log_events: events)}
  end

  @impl true
  def handle_event("close_event_log", _params, socket) do
    {:noreply, assign(socket, event_log_job: nil, event_log_events: [])}
  end

  @impl true
  def handle_event("close_event_materials", _params, socket) do
    {:noreply, assign(socket, :event_materials_event, nil)}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  defp job_card(assigns) do
    ~H"""
    <div
      class={["jcard", @job.status == :in_progress && "live"]}
      phx-click="open_event_log"
      phx-value-id={@job.id}
      ontouchstart=""
    >
      <%!-- top: who + status pill --%>
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
              <path d="M12 21s7-5.5 7-11a7 7 0 1 0-14 0c0 5.5 7 11 7 11Z" stroke="#9A9384" stroke-width="1.6" />
              <circle cx="12" cy="10" r="2.4" stroke="#9A9384" stroke-width="1.6" />
            </svg>
            {job_where_text(@job)}
          </div>
        </div>
        <span :if={@job.status == :in_progress} class="pill live">
          <span class="dot pulse"></span>On site
        </span>
        <span :if={@job.status == :scheduled} class="pill sched">
          <span class="dot"></span>Scheduled
        </span>
        <span :if={@job.status == :completed} class="pill done">Done</span>
        <span :if={@job.status == :cancelled} class="pill cancel">Cancelled</span>
      </div>

      <%!-- meta: category --%>
      <div style="margin-top:11px;">
        <span :if={@job.service_category} class="jcat">
          <span class="catdot" style={"background:#{category_color(@job.service_category)}"}></span>
          {service_category_label(@job.service_category)}
        </span>
        <span :if={!@job.service_category} class="jcat" style="color:#6E675A;">—</span>
      </div>

      <%!-- live strip (in-progress) --%>
      <div :if={@job.status == :in_progress} class="live-strip">
        <span class="lbl">{live_strip_label(@job)}</span>
        <button class="open" type="button" phx-click="open_event_log" phx-value-id={@job.id}>
          Open
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M9 6l6 6-6 6" stroke="#54B57E" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </button>
      </div>

      <%!-- crew row (scheduled + crew present) --%>
      <div
        :if={@job.status != :in_progress && @job.staff_assignments != [] && @job.staff_assignments != nil}
        class="crewrow"
      >
        <div class="avs">
          <div
            :for={sa <- Enum.take(@job.staff_assignments, 5)}
            class="av"
            style={"background:#{crew_color(sa.member_id)}"}
          >
            {crew_initial(sa.member)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp jobs_for_tab(jobs, :today, today) do
    jobs
    |> Enum.filter(&job_today?(&1, today))
    |> Enum.sort_by(fn j -> if j.status == :in_progress, do: 0, else: 1 end)
  end

  defp jobs_for_tab(jobs, :upcoming, today) do
    jobs
    |> Enum.filter(&job_upcoming?(&1, today))
    |> Enum.sort_by(& &1.scheduled_for, Date)
  end

  defp jobs_for_tab(jobs, :done, _today) do
    Enum.filter(jobs, &job_done?/1)
  end

  defp group_by_date(jobs) do
    jobs
    |> Enum.group_by(& &1.scheduled_for)
    |> Enum.sort_by(fn {date, _} -> date end, Date)
  end

  defp day_group_label(date, today) do
    cond do
      Date.compare(date, Date.add(today, 1)) == :eq -> "Tomorrow"
      true -> Calendar.strftime(date, "%A")
    end
  end

  defp day_date_label(date, today) do
    if Date.diff(date, today) > 1 do
      Calendar.strftime(date, "%-d %B")
    else
      Calendar.strftime(date, "%a %-d %b")
    end
  end

  defp job_who(job) do
    cl = customer_label(job)
    if cl != "", do: cl, else: (job.garden && (job.garden.name || "Unnamed site")) || "Unnamed job"
  end

  defp job_where_text(%{garden: nil}), do: nil

  defp job_where_text(%{garden: g}) do
    parts = [g.name, g.zip] |> Enum.reject(&is_nil/1) |> Enum.reject(&(&1 == ""))
    if parts == [], do: nil, else: Enum.join(parts, " · ")
  end

  defp crew_initial(%{display_title: dt}) when is_binary(dt) and dt != "" do
    dt |> String.trim() |> String.first() |> String.upcase()
  end

  defp crew_initial(_), do: "?"

  defp crew_color(member_id) do
    colors = ["#6BCB93", "#DB9258", "#5AB4D8", "#A87EDB", "#E87E7E"]
    Enum.at(colors, :erlang.phash2(member_id, length(colors)))
  end

  defp live_strip_label(job) do
    names =
      job.staff_assignments
      |> Enum.take(3)
      |> Enum.map(fn sa ->
        dt = sa.member && sa.member.display_title
        if is_binary(dt) and dt != "", do: String.split(dt) |> hd(), else: nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" + ")

    if names != "", do: "on the clock · #{names}", else: "on the clock"
  end

  defp category_color(:installation), do: "#DB9258"
  defp category_color(:delivery), do: "#DB9258"
  defp category_color(:consultation), do: "#5AB4D8"
  defp category_color(:design), do: "#5AB4D8"
  defp category_color(_), do: "#54B57E"

  defp load_jobs(socket) do
    member = socket.assigns.current_member

    jobs =
      Orders.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer], staff_assignments: [:member]]
      )

    today = Date.utc_today()

    counts = %{
      today: Enum.count(jobs, &job_today?(&1, today)),
      upcoming: Enum.count(jobs, &job_upcoming?(&1, today)),
      done: Enum.count(jobs, &job_done?/1)
    }

    socket |> assign(:jobs, jobs) |> assign(:counts, counts)
  end

  defp job_today?(job, today) do
    job.status == :in_progress or
      (job.scheduled_for && Date.compare(job.scheduled_for, today) == :eq &&
         job.status == :scheduled)
  end

  defp job_upcoming?(job, today) do
    job.status == :scheduled and job.scheduled_for != nil and
      Date.compare(job.scheduled_for, today) == :gt
  end

  defp job_done?(job), do: job.status in [:completed, :cancelled]

  defp event_log_title(job) do
    site = site_label(job)
    customer = customer_label(job)
    if customer == "", do: site, else: "#{site} · #{customer}"
  end

  defp site_label(%{garden: nil}), do: "No site set"

  defp site_label(%{garden: garden}) do
    garden.name || "Unnamed site"
  end

  defp customer_label(%{engagement: nil}), do: ""
  defp customer_label(%{engagement: %{customer: nil}}), do: ""

  defp customer_label(%{engagement: %{customer: c}}) do
    if c.company_name_nickname,
      do: c.company_name_nickname,
      else: "#{c.first_name} #{c.last_name}"
  end

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
