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
          {customer_label(job.customer)}
        </div>
      </:col>

      <:col :let={job} label="Date">
        <span :if={job.scheduled_at}>
          {format_date(job.scheduled_at, format: "%d %b %Y")}
        </span>
        <span :if={!job.scheduled_at} class="text-stone-400">—</span>
      </:col>

      <:col :let={job} label="Time">
        <span :if={job.scheduled_at}>
          {format_date(job.scheduled_at, format: "%H:%M")}
        </span>
        <span :if={!job.scheduled_at} class="text-stone-400">—</span>
      </:col>

      <:col :let={job} label="Duration">
        {job_duration(job)}
      </:col>

      <:col :let={job} label="Type">
        {service_type_label(job.service_type)}
      </:col>

      <:col :let={job} label="Status">
        <.badge
          text={job.status}
          colors={[
            {:scheduled, "text-blue-700 bg-blue-50"},
            {:completed, "text-green-700 bg-green-50"},
            {:cancelled, "text-stone-500 bg-stone-100"}
          ]}
        />
      </:col>

      <:col :let={job} label="Invoiced">
        <input
          type="checkbox"
          checked={job.invoiced}
          phx-click="toggle_invoiced"
          phx-value-id={job.id}
          class="rounded border-stone-300 text-primary-600 cursor-pointer"
        />
      </:col>

      <:action :let={job}>
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
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_jobs(socket)}
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
        load: [:customer, :address]
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
  def handle_event("toggle_invoiced", %{"id" => id}, socket) do
    member = socket.assigns.current_member

    job =
      Orders.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id
      )

    {:ok, _} =
      Orders.update_job(job, %{invoiced: !job.invoiced},
        actor: member,
        tenant: member.organisation_id
      )

    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    member = socket.assigns.current_member

    jobs =
      Orders.list_jobs!(
        actor: member,
        tenant: member.organisation_id,
        load: [:customer, :address]
      )

    assign(socket, :jobs, jobs)
  end

  defp site_label(%{address: nil}), do: "No site set"
  defp site_label(%{address: addr}) do
    type = if addr.is_indoor, do: "indoor", else: "garden"
    addr.name || "Unnamed #{type}"
  end

  defp customer_label(nil), do: ""
  defp customer_label(c) do
    if c.company_name_nickname,
      do: c.company_name_nickname,
      else: "#{c.first_name} #{c.last_name}"
  end

  # Planned (scheduled): shown in parentheses like accounting negative
  defp job_duration(%{status: :scheduled, estimated_duration_minutes: nil}), do: "—"
  defp job_duration(%{status: :scheduled, estimated_duration_minutes: min}) do
    "(#{format_minutes(min)})"
  end

  # Completed: show estimated duration as positive (actual from events comes later)
  defp job_duration(%{status: :completed, estimated_duration_minutes: nil}), do: "—"
  defp job_duration(%{status: :completed, estimated_duration_minutes: min}) do
    format_minutes(min)
  end

  defp job_duration(_), do: "—"

  defp format_minutes(min) when min < 60, do: "#{min}m"
  defp format_minutes(min) do
    h = div(min, 60)
    m = rem(min, 60)
    if m == 0, do: "#{h}h", else: "#{h}h #{m}m"
  end

  defp service_type_label(:installation), do: "Installation"
  defp service_type_label(:maintenance), do: "Maintenance"
  defp service_type_label(:delivery), do: "Delivery"
  defp service_type_label(:consultation), do: "Consultation"
  defp service_type_label(:pruning), do: "Pruning"
  defp service_type_label(:open_garden), do: "Open garden"
  defp service_type_label(:winterize_garden), do: "Winterize"
  defp service_type_label(other), do: to_string(other)
end
