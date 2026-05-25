defmodule OpenSauceWeb.JobLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Orders
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Jobs
      <:actions>
        <.link patch={~p"/manage/jobs/new"}>
          <.button variant={:primary}>New Job</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="jobs" rows={@jobs}>
      <:empty>
        <div class="py-6 text-center text-sm text-stone-500">
          No jobs scheduled yet.
        </div>
      </:empty>

      <:col :let={job} label="Garden / Site">
        <div class="font-medium text-stone-900">
          {site_label(job)}
        </div>
        <div class="text-xs text-stone-500">
          {customer_label(job)}
        </div>
      </:col>

      <:col :let={job} label="Date">
        <span :if={job.scheduled_for}>
          {format_date(job.scheduled_for, format: "%d %b %Y")}
        </span>
        <span :if={!job.scheduled_for} class="text-stone-400">—</span>
      </:col>

      <:col :let={job} label="Cost">
        <div class="text-red-600">({format_money(@organisation.currency, job.materials_cost)})</div>
      </:col>

      <:col :let={job} label="Duration">
        {job_duration(job)}
      </:col>

      <:col :let={job} label="Category">
        {service_category_label(job.service_category)}
      </:col>

      <:col :let={job} label="Status">
        <button
          phx-click="open_event_log"
          phx-value-id={job.id}
          class="cursor-pointer rounded focus:outline-none focus:ring-2 focus:ring-primary-500"
          title="Log event or change status"
        >
          <.badge
            text={job.status}
            colors={[
              {:planned, "text-blue-700 bg-blue-50"},
              {:in_progress, "text-amber-700 bg-amber-50"},
              {:completed, "text-green-700 bg-green-50"},
              {:cancelled, "text-stone-500 bg-stone-100"}
            ]}
          />
        </button>
      </:col>

      <:action :let={job}>
        <button
          phx-click="open_materials"
          phx-value-id={job.id}
          class="text-sm text-stone-500 hover:text-stone-700"
        >
          Materials
        </button>
        <.link patch={~p"/manage/jobs/#{job.id}/edit"} class="text-sm text-stone-500 hover:text-stone-700">
          Edit
        </.link>
      </:action>
    </.table>

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

    if event.data.type == :arrival && job.status == :planned do
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

  defp load_jobs(socket) do
    member = socket.assigns.current_member

    jobs =
      Orders.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:garden, :duration, :materials_cost, engagement: [:customer]]
      )

    assign(socket, :jobs, jobs)
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
    if c.company_name_nickname,
      do: c.company_name_nickname,
      else: "#{c.first_name} #{c.last_name}"
  end

  defp job_duration(%{duration: minutes}) when is_integer(minutes) do
    format_minutes(minutes)
  end

  defp job_duration(_), do: "—"

  defp format_minutes(min) when min < 60, do: "#{min}m"

  defp format_minutes(min) do
    h = div(min, 60)
    m = rem(min, 60)
    if m == 0, do: "#{h}h", else: "#{h}h #{m}m"
  end

  defp service_category_label(nil), do: "—"
  defp service_category_label(:installation), do: "Installation"
  defp service_category_label(:delivery), do: "Delivery"
  defp service_category_label(:pruning), do: "Pruning"
  defp service_category_label(:consultation), do: "Consultation"
  defp service_category_label(:design), do: "Design"
  defp service_category_label(:opening), do: "Opening"
  defp service_category_label(:winterization), do: "Winterization"
  defp service_category_label(:nursery_run), do: "Nursery run"
  defp service_category_label(:other), do: "Other"
  defp service_category_label(other), do: to_string(other)
end
