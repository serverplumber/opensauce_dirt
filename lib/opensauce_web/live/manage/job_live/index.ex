defmodule OpenSauceWeb.JobLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts
  alias OpenSauce.Work
  alias OpenSauceWeb.JobLive.EventLogComponent

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
          <button
            class={["seg-tab", @tab == :scheduled && "seg-tab--on"]}
            type="button"
            phx-click="set_tab"
            phx-value-tab="scheduled"
          >
            Scheduled
            <span :if={@counts.scheduled > 0} style="font-size:11px;font-weight:700;opacity:0.7;">
              {@counts.scheduled}
            </span>
          </button>
          <button
            class={["seg-tab", @tab == :unscheduled && "seg-tab--on"]}
            type="button"
            phx-click="set_tab"
            phx-value-tab="unscheduled"
          >
            Unscheduled
            <span :if={@counts.unscheduled > 0} style="font-size:11px;font-weight:700;opacity:0.7;">
              {@counts.unscheduled}
            </span>
          </button>
          <button
            class={["seg-tab", @tab == :history && "seg-tab--on"]}
            type="button"
            phx-click="set_tab"
            phx-value-tab="history"
          >
            History
          </button>
        </div>
      </div>

      <%!-- job list --%>
      <% today = Date.utc_today() %>
      <div style="padding:4px 16px 100px;">
        <%!-- scheduled tab: grouped by date ascending --%>
        <div :if={@tab == :scheduled}>
          <div :if={@counts.scheduled > 0}>
            <div :for={
              {date, date_jobs} <- group_scheduled(jobs_for_tab(@jobs, :scheduled, today), today)
            }>
              <div class="dayrow">
                <span class="dl">{day_group_label(date, today)}</span>
                <span class="line"></span>
                <span class="dn">{day_date_label(date, today)}</span>
              </div>
              <.job_card :for={job <- date_jobs} job={job} org_members={@org_members} />
            </div>
          </div>
          <div
            :if={@counts.scheduled == 0}
            style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;"
          >
            Nothing scheduled
          </div>
        </div>

        <%!-- unscheduled tab: flat list --%>
        <div :if={@tab == :unscheduled}>
          <div :if={@counts.unscheduled > 0}>
            <.job_card :for={job <- jobs_for_tab(@jobs, :unscheduled, today)} job={job} org_members={@org_members} />
          </div>
          <div
            :if={@counts.unscheduled == 0}
            style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;"
          >
            No unscheduled jobs
          </div>
        </div>

        <%!-- history tab: grouped by date descending --%>
        <div :if={@tab == :history}>
          <div :if={@counts.history > 0}>
            <div :for={{date, date_jobs} <- group_history(jobs_for_tab(@jobs, :history, today))}>
              <div class="dayrow">
                <span class="dl">{history_group_label(date, today)}</span>
                <span class="line"></span>
                <span :if={date != nil} class="dn">{day_date_label(date, today)}</span>
              </div>
              <.job_card :for={job <- date_jobs} job={job} org_members={@org_members} />
            </div>
          </div>
          <div
            :if={@counts.history == 0}
            style="margin-top:32px;text-align:center;color:#6E675A;font-size:14px;font-weight:600;"
          >
            No history yet
          </div>
        </div>
      </div>
    </div>

    <%!-- floating action button --%>
    <button
      class="fab"
      type="button"
      phx-click={JS.patch(~p"/manage/jobs/new")}
      ontouchstart=""
      title="New job"
    >
      <.add_job_icon />
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
       tab: :scheduled,
       org_members: [],
       active_shift: nil,
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
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Job")
    |> assign(:job, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    member = socket.assigns.current_member

    job =
      Work.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, engagement: [:customer]]
      )

    socket
    |> assign(:page_title, "Edit Job")
    |> assign(:job, job)
  end

  @impl true
  def handle_info({OpenSauceWeb.JobLive.FormComponent, {:saved, _job}}, socket) do
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_info({EventLogComponent, {:manage_event_materials, event}}, socket) do
    {:noreply,
     socket
     |> assign(event_log_job: nil, event_log_events: [])
     |> assign(event_materials_event: event)}
  end

  @impl true
  def handle_info({EventLogComponent, {:event_logged, event}}, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.event_log_job

    if event.data.type == :arrival && job.status == :scheduled do
      Work.mark_job_in_progress(job, actor: member, tenant: member.organisation_id)
    end

    {:noreply, socket |> assign(event_log_job: nil, event_log_events: []) |> load_jobs()}
  end

  @impl true
  def handle_info({EventLogComponent, {:status_changed, status}}, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.event_log_job
    opts = [actor: member, tenant: member.organisation_id]

    case status do
      :completed -> Work.complete_job(job, opts)
      :cancelled -> Work.cancel_job(job, opts)
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
      Work.list_job_events!(job.id,
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

  defp jobs_for_tab(jobs, :scheduled, today) do
    Enum.filter(jobs, &job_scheduled?(&1, today))
  end

  defp jobs_for_tab(jobs, :unscheduled, _today) do
    Enum.filter(jobs, &job_unscheduled?/1)
  end

  defp jobs_for_tab(jobs, :history, today) do
    Enum.filter(jobs, &job_history?(&1, today))
  end

  defp group_scheduled(jobs, today) do
    today_jobs =
      jobs
      |> Enum.filter(fn j ->
        j.status == :in_progress or
          (j.scheduled_for && Date.compare(j.scheduled_for, today) == :eq)
      end)
      |> Enum.sort_by(fn j -> if j.status == :in_progress, do: 0, else: 1 end)

    future_groups =
      jobs
      |> Enum.filter(fn j ->
        j.status == :scheduled and j.scheduled_for != nil and
          Date.after?(j.scheduled_for, today)
      end)
      |> Enum.group_by(& &1.scheduled_for)
      |> Enum.sort_by(fn {date, _} -> date end, Date)

    today_group = if today_jobs == [], do: [], else: [{today, today_jobs}]
    today_group ++ future_groups
  end

  defp group_history(jobs) do
    {dated, undated} = Enum.split_with(jobs, &(&1.scheduled_for != nil))

    dated_groups =
      dated
      |> Enum.group_by(& &1.scheduled_for)
      |> Enum.sort_by(fn {date, _} -> date end, {:desc, Date})

    if undated == [], do: dated_groups, else: dated_groups ++ [{nil, undated}]
  end

  defp day_group_label(date, today) do
    cond do
      Date.compare(date, today) == :eq -> "Today"
      Date.compare(date, Date.add(today, 1)) == :eq -> "Tomorrow"
      true -> Calendar.strftime(date, "%A")
    end
  end

  defp history_group_label(nil, _today), do: "Undated"

  defp history_group_label(date, today) do
    if Date.compare(date, Date.add(today, -1)) == :eq,
      do: "Yesterday",
      else: Calendar.strftime(date, "%A")
  end

  defp day_date_label(date, today) do
    if Date.diff(date, today) > 1 do
      Calendar.strftime(date, "%-d %B")
    else
      Calendar.strftime(date, "%a %-d %b")
    end
  end

  defp load_jobs(socket) do
    member = socket.assigns.current_member

    org_members = Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)

    all_jobs =
      Work.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, :staff_assignments, engagement: [:customer]]
      )

    active_shift = Enum.find(all_jobs, &(&1.type == :shift && &1.status == :in_progress))
    jobs = Enum.reject(all_jobs, &(&1.type == :shift))

    today = Date.utc_today()

    counts = %{
      scheduled: Enum.count(jobs, &job_scheduled?(&1, today)),
      unscheduled: Enum.count(jobs, &job_unscheduled?/1),
      history: Enum.count(jobs, &job_history?(&1, today))
    }

    socket
    |> assign(:jobs, jobs)
    |> assign(:counts, counts)
    |> assign(:org_members, org_members)
    |> assign(:active_shift, active_shift)
  end

  defp job_scheduled?(job, today) do
    job.status == :in_progress or
      (job.scheduled_for != nil and Date.compare(job.scheduled_for, today) != :lt and
         job.status == :scheduled)
  end

  defp job_unscheduled?(job), do: job.status == :scheduling

  defp job_history?(job, today) do
    job.status in [:completed, :cancelled] or
      (job.scheduled_for != nil and Date.before?(job.scheduled_for, today) and
         job.status not in [:scheduling])
  end

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
    if c.company_name_nickname, do: c.company_name_nickname, else: "#{c.first_name} #{c.last_name}"
  end
end
