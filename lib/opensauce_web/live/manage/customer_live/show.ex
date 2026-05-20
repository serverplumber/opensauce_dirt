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
        <.button variant={:outline} phx-click="delete" data-confirm="Delete this customer?">
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

      <.tabs_content :if={@live_action in [:engagements, :new_engagement, :edit_engagement]}>
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
              {format_money(@settings.currency, e.install_price)}
            </:col>
            <:col :let={e} label="Annual maintenance">
              {format_money(@settings.currency, e.maintenance_price_annual)}
            </:col>
            <:col :let={e} label="Term">
              {format_term(e.term_start, e.term_end)}
            </:col>
            <:action :let={e}>
              <.link patch={~p"/manage/customers/#{@customer.reference}/engagements/#{e.id}/plants"}>
                <.button variant={:outline}>Plants</.button>
              </.link>
            </:action>
          </.table>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :orders}>
        <div class="mt-6 space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Orders History</h3>
            <.link navigate={~p"/manage/orders/new?customer_id=#{@customer.reference}"}>
              <.button variant={:primary}>New Order</.button>
            </.link>
          </div>

          <.table
            id="customer_orders"
            rows={@customer.orders}
            row_click={fn order -> JS.navigate(~p"/manage/orders/#{order.reference}") end}
          >
            <:col :let={order} label="Reference">
              <.kbd>{order.reference}</.kbd>
            </:col>
            <:col :let={order} label="Status">
              <.badge
                text={order.status}
                colors={[
                  {order.status,
                   "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
                ]}
              />
            </:col>
            <:col :let={order} label="Created at">
              {format_time(order.inserted_at, @time_zone)}
            </:col>
            <:col :let={order} label="Delivery Date">
              {format_time(order.delivery_date, @time_zone)}
            </:col>
            <:col :let={order} label="Total">
              {format_money(@settings.currency, order.total_cost)}
            </:col>
          </.table>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :statistics}>
        <div class="mt-6 space-y-8">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <.stat_card title="Total Orders" value={@customer.total_orders} />
            <.stat_card
              title="Total Spent"
              value={format_money(@settings.currency, @customer.total_orders_value)}
            />
          </div>
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
      :if={@live_action == :engagement_plants}
      id="engagement-plants-modal"
      title="Plants"
      max_width="max-w-3xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}/engagements")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.PlantsComponent}
        id={"plants-#{@engagement_id}"}
        engagement_id={@engagement_id}
        current_member={@current_member}
        currency={@settings.currency}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:engagement, nil) |> assign(:engagement_id, nil)}
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
        active: live_action in [:engagements, :new_engagement, :edit_engagement, :engagement_plants]
      },
      %{
        label: "Orders",
        navigate: ~p"/manage/customers/#{customer.reference}/orders",
        active: live_action == :orders
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
  def handle_info({OpenSauceWeb.CustomerLive.FormComponent, {:saved, customer}}, socket) do
    {:noreply, assign(socket, :customer, load_customer(customer.reference, socket))}
  end

  def handle_info({OpenSauceWeb.EngagementLive.FormComponent, {:saved, _engagement}}, socket) do
    customer = load_customer(socket.assigns.customer.reference, socket)
    {:noreply, assign(socket, :customer, customer)}
  end

  defp load_customer(reference, socket) do
    CRM.get_customer_by_reference!(
      reference,
      actor: socket.assigns.current_member,
      tenant: socket.assigns.current_member.organisation_id,
      load: [
        :full_name,
        :total_orders_value,
        :total_orders,
        orders: [:total_cost, :total_items],
        billing_address: [:full_address],
        garden_addresses: [:name, :short_address, :full_address],
        engagements: [:total_quoted_value, garden: [:name]]
      ]
    )
  end

  defp page_title(:show), do: "Customer"
  defp page_title(:details), do: "Customer Details"
  defp page_title(:edit), do: "Edit Customer"
  defp page_title(:engagements), do: "Engagements"
  defp page_title(:new_engagement), do: "New Engagement"
  defp page_title(:edit_engagement), do: "Edit Engagement"
  defp page_title(:engagement_plants), do: "Plants"
  defp page_title(:orders), do: "Customer Orders"
  defp page_title(:statistics), do: "Customer Statistics"

  defp customer_trail(customer, live_action)
       when live_action in [:engagements, :new_engagement, :edit_engagement, :engagement_plants] do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_engagements, customer)
    ]
  end

  defp customer_trail(customer, :orders) do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_orders, customer)
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
