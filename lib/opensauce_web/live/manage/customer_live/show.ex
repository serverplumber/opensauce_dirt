defmodule OpenSauceWeb.CustomerLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@customer.company_name_nickname}
      <:actions>
        <.link patch={~p"/manage/customers/#{@customer.reference}/edit"}>
          <.button variant={:outline}>Edit</.button>
        </.link>
        <.button variant={:outline} phx-click="delete">
          Delete
        </.button>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="p mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <div class="mt-8 space-y-8">
          <div class="grid grid-cols-1 gap-8 md:grid-cols-2">
            <.list>
              <:item title="Type"><.badge text={@customer.type} /></:item>
              <:item title="Name">{@customer.full_name}</:item>
              <:item title="Email">{@customer.email}</:item>
              <:item title="Phone">{@customer.phone}</:item>
              <:item :if={@customer.billing_address} title="Billing Address">
                {@customer.billing_address.full_address}
              </:item>
              <:item :for={addr <- @customer.garden_addresses} title={addr.name || "Garden Address"}>
                {addr.full_address}
              </:item>
            </.list>
          </div>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action in [:engagements, :new_engagement, :edit_engagement, :engagement_materials]}>
        <div class="mt-6 space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Engagements</h3>
            <.link patch={~p"/manage/customers/#{@customer.reference}/engagements/new"}>
              <.button variant={:primary}>New Engagement</.button>
            </.link>
          </div>

          <.table
            id="customer_engagements"
            rows={@customer.engagements}
            row_click={fn e -> JS.patch(~p"/manage/customers/#{@customer.reference}/engagements/#{e.id}/edit") end}
          >
            <:col :let={e} label="Garden">
              {if e.garden, do: e.garden.name || "Garden", else: "—"}
            </:col>
            <:col :let={e} label="Status">
              <.badge
                text={e.status}
                colors={[{e.status, engagement_status_class(e.status)}]}
              />
            </:col>
            <:col :let={e} label="Install">
              {format_money(@organisation.currency, e.install_price)}
            </:col>
            <:col :let={e} label="Annual maintenance">
              {format_money(@organisation.currency, e.maintenance_price_annual)}
            </:col>
            <:col :let={e} label="Term">
              {format_term(e.term_start, e.term_end)}
            </:col>
            <:action :let={e}>
              <.button variant={:outline} phx-click="open_schedule_job" phx-value-id={e.id}>
                New job
              </.button>
              <.link patch={~p"/manage/customers/#{@customer.reference}/engagements/#{e.id}/materials"}>
                <.button variant={:outline}>Materials</.button>
              </.link>
            </:action>
          </.table>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :statistics}>
        <div class="mt-6 space-y-8">
          <p class="text-sm text-stone-500">No statistics available yet.</p>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="customer-modal"
      title="Edit Customer"
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}/details")}
    >
      <.live_component
        module={OpenSauceWeb.CustomerLive.FormComponent}
        id={@customer.id}
        current_member={@current_member}
        action={@live_action}
        customer={@customer}
        patch={~p"/manage/customers/#{@customer.reference}/details"}
      />
    </.modal>

    <.modal
      :if={@live_action == :new_engagement}
      id="engagement-new-modal"
      title="New Engagement"
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}/engagements")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.FormComponent}
        id="engagement-new"
        current_member={@current_member}
        engagement={nil}
        customer={@customer}
        patch={~p"/manage/customers/#{@customer.reference}/engagements"}
      />
    </.modal>

    <.modal
      :if={@live_action == :edit_engagement}
      id="engagement-edit-modal"
      title="Edit Engagement"
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}/engagements")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.FormComponent}
        id={"engagement-#{@engagement && @engagement.id}"}
        current_member={@current_member}
        engagement={@engagement}
        customer={@customer}
        patch={~p"/manage/customers/#{@customer.reference}/engagements"}
      />
    </.modal>

    <.modal
      :if={@live_action == :engagement_materials}
      id="engagement-materials-modal"
      title="Materials"
      max_width="max-w-3xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}/engagements")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.MaterialsComponent}
        id={"materials-#{@engagement_id}"}
        engagement_id={@engagement_id}
        current_member={@current_member}
        currency={@organisation.currency}
      />
    </.modal>

    <.modal
      :if={@schedule_job_engagement != nil}
      id="schedule-job-modal"
      title={"New job — #{schedule_job_title(@schedule_job_engagement)}"}
      max_width="max-w-xl"
      show
      on_cancel={JS.push("close_schedule_job")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.ScheduleJobComponent}
        id={"schedule-job-#{@schedule_job_engagement.id}"}
        engagement={@schedule_job_engagement}
        current_member={@current_member}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:engagement, nil)
     |> assign(:engagement_id, nil)
     |> assign(:schedule_job_engagement, nil)}
  end

  @impl true
  def handle_params(%{"reference" => reference} = params, _, socket) do
    customer = load_customer(reference, socket)
    live_action = socket.assigns.live_action

    engagement =
      if live_action == :edit_engagement do
        Enum.find(customer.engagements, &(&1.id == params["engagement_id"]))
      end

    engagement_id = params["engagement_id"]

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/customers/#{customer.reference}/details",
        active: live_action in [:details, :show, :edit]
      },
      %{
        label: "Engagements",
        navigate: ~p"/manage/customers/#{customer.reference}/engagements",
        active: live_action in [:engagements, :new_engagement, :edit_engagement, :engagement_materials]
      },
      %{
        label: "Statistics",
        navigate: ~p"/manage/customers/#{customer.reference}/statistics",
        active: live_action == :statistics
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:customer, customer)
      |> assign(:engagement, engagement)
      |> assign(:engagement_id, engagement_id)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :customers, customer_trail(customer, live_action))}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case CRM.destroy_customer(socket.assigns.customer,
           actor: socket.assigns.current_member,
           tenant: socket.assigns.current_member.organisation_id
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer deleted.")
         |> push_navigate(to: ~p"/manage/customers")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete customer.")}
    end
  end

  @impl true
  def handle_event("open_schedule_job", %{"id" => id}, socket) do
    engagement = Enum.find(socket.assigns.customer.engagements, &(&1.id == id))
    {:noreply, assign(socket, :schedule_job_engagement, engagement)}
  end

  def handle_event("close_schedule_job", _params, socket) do
    {:noreply, assign(socket, :schedule_job_engagement, nil)}
  end

  @impl true
  def handle_info({OpenSauceWeb.CustomerLive.FormComponent, {:saved, customer}}, socket) do
    {:noreply, assign(socket, :customer, load_customer(customer.reference, socket))}
  end

  def handle_info({OpenSauceWeb.EngagementLive.FormComponent, {:saved, _engagement}}, socket) do
    customer = load_customer(socket.assigns.customer.reference, socket)
    {:noreply, assign(socket, :customer, customer)}
  end

  def handle_info(
        {OpenSauceWeb.EngagementLive.ScheduleJobComponent, {:job_created, _job, count}},
        socket
      ) do
    customer = load_customer(socket.assigns.customer.reference, socket)

    {:noreply,
     socket
     |> assign(:customer, customer)
     |> assign(:schedule_job_engagement, nil)
     |> put_flash(:info, "Job scheduled with #{count} plant#{if count == 1, do: "", else: "s"}.")}
  end

  defp load_customer(reference, socket) do
    CRM.get_customer_by_reference!(
      reference,
      actor: socket.assigns.current_member,
      tenant: socket.assigns.current_member.organisation_id,
      load: [
        :full_name,
        billing_address: [:full_address],
        garden_addresses: [:name, :short_address, :full_address],
        engagements: [:total_quoted_value, :materials, garden: [:name]]
      ]
    )
  end

  defp page_title(:show), do: "Customer"
  defp page_title(:details), do: "Customer Details"
  defp page_title(:edit), do: "Edit Customer"
  defp page_title(:engagements), do: "Engagements"
  defp page_title(:new_engagement), do: "New Engagement"
  defp page_title(:edit_engagement), do: "Edit Engagement"
  defp page_title(:engagement_materials), do: "Materials"
  defp page_title(:statistics), do: "Customer Statistics"

  defp customer_trail(customer, live_action)
       when live_action in [
              :engagements,
              :new_engagement,
              :edit_engagement,
              :engagement_materials
            ] do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_engagements, customer)
    ]
  end

  defp customer_trail(customer, :statistics) do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_statistics, customer)
    ]
  end

  defp customer_trail(customer, _),
    do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]

  defp schedule_job_title(engagement) do
    if engagement.garden, do: engagement.garden.name || "garden", else: "engagement"
  end

  defp format_term(nil, nil), do: "—"
  defp format_term(start, nil), do: "From #{Date.to_iso8601(start)}"
  defp format_term(nil, end_date), do: "Until #{Date.to_iso8601(end_date)}"
  defp format_term(start, end_date), do: "#{Date.to_iso8601(start)} → #{Date.to_iso8601(end_date)}"

  defp engagement_status_class(:draft), do: "text-gray-600 bg-gray-100"
  defp engagement_status_class(:proposed), do: "text-amber-700 bg-amber-100"
  defp engagement_status_class(:signed), do: "text-blue-700 bg-blue-100"
  defp engagement_status_class(:in_progress), do: "text-green-700 bg-green-100"
  defp engagement_status_class(:completed), do: "text-emerald-700 bg-emerald-100"
  defp engagement_status_class(:cancelled), do: "text-red-700 bg-red-100"
  defp engagement_status_class(_), do: "text-gray-600 bg-gray-100"
end
