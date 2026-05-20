defmodule OpenSauceWeb.OrderLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Catalog
  alias OpenSauce.Catalog.Product.Photo
  alias OpenSauce.CRM
  alias OpenSauce.Orders
  alias OpenSauceWeb.Navigation

  @default_order_load [
    :total_cost,
    items: [:cost, :status, product: [:name, :sku]],
    customer: [:full_name, billing_address: [:full_address]]
  ]

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@order.reference}
      <:actions>
        <.link patch={~p"/manage/orders/#{@order.reference}/edit"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Edit order</.button>
        </.link>
        <.link href={~p"/manage/orders/#{@order.reference}/invoice.pdf"} target="_blank">
          <.button variant={:outline}>View Invoice</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show, :edit]}>
        <.list>
          <:item title="Reference">
            <.kbd>
              {format_reference(@order.reference)}
            </.kbd>
          </:item>

          <:item title="Status">
            <.badge
              text={@order.status}
              colors={[
                {@order.status,
                 "#{order_status_color(@order.status)} #{order_status_bg(@order.status)}"}
              ]}
            />
          </:item>

          <:item title="Customer">
            <.link
              class="hover:text-blue-800 hover:underline"
              navigate={~p"/manage/customers/#{@order.customer.reference}"}
            >
              {@order.customer.full_name}
            </.link>
          </:item>
          <:item title="Billing Address">
            {if @order.customer.billing_address do
              @order.customer.billing_address.full_address
            else
              "N/A"
            end}
          </:item>

          <:item title="Total">
            {format_money(@settings.currency, @order.total_cost)}
          </:item>

          <:item title="Delivery Date">
            {format_time(@order.delivery_date, @time_zone)}
          </:item>

          <:item title="Created At">
            {format_time(@order.inserted_at, @time_zone)}
          </:item>
        </.list>
      </.tabs_content>

      <.tabs_content :if={@live_action == :items}>
        <.table id="order-items" rows={@order.items}>
          <:col :let={item} label="Product">
            <.link
              class="hover:text-blue-800 hover:underline"
              navigate={~p"/manage/products/#{item.product.sku}"}
            >
              <div class="flex items-center space-x-2">
                <img
                  :if={item.product.featured_photo != nil}
                  src={Photo.url({item.product.featured_photo, item.product}, :thumb, signed: true)}
                  alt={item.product.name}
                  class="h-5 w-5"
                />
                <span>
                  {item.product.name}
                </span>
              </div>
            </.link>
          </:col>
          <:col :let={item} label="Quantity">{item.quantity}</:col>
          <:col :let={item} label="Unit Price">
            {format_money(@settings.currency, item.product.price)}
          </:col>
          <:col :let={item} label="Total">
            {format_money(@settings.currency, item.cost)}
          </:col>
          <:col :let={item} label="Status">
            <.badge
              text={item.status}
              colors={[
                {:todo, "#{order_item_status_bg(:todo)} #{order_item_status_color(:todo)}"},
                {:in_progress,
                 "#{order_item_status_bg(:in_progress)} #{order_item_status_color(:in_progress)}"},
                {:done, "#{order_item_status_bg(:done)} #{order_item_status_color(:done)}"}
              ]}
            />
          </:col>
        </.table>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="order-modal"
      show
      title={@page_title}
      on_cancel={JS.patch(~p"/manage/orders/#{@order.reference}")}
    >
      <.live_component
        module={OpenSauceWeb.OrderLive.FormComponent}
        id={(@order && @order.id) || :new}
        current_member={@current_member}
        title={@page_title}
        action={@live_action}
        order={@order}
        products={@products}
        customers={@customers}
        settings={@settings}
        patch={~p"/manage/orders/#{@order.reference}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id)

    customers =
      CRM.list_customers!(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id, load: [:full_name])

    {:ok, assign(socket, products: products, customers: customers)}
  end

  @impl true
  def handle_params(%{"reference" => reference}, _, socket) do
    order =
      Orders.get_order_by_reference!(reference,
        load: @default_order_load,
        actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/orders/#{order.reference}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Items",
        navigate: ~p"/manage/orders/#{order.reference}/items",
        active: live_action == :items
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:order, order)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :orders, order_trail(order, live_action))}
  end

  @impl true
  def handle_info({OpenSauceWeb.OrderLive.FormComponentItems, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id
      )

    {:noreply,
     socket
     |> put_flash(:info, "Order items updated successfully")
     |> assign(:order, order)
     |> push_event("close-modal", %{id: "order-item-modal"})}
  end

  @impl true
  def handle_info({OpenSauceWeb.OrderLive.FormComponent, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id
      )

    {:noreply,
     socket
     |> put_flash(:info, "Order updated successfully")
     |> assign(:order, order)}
  end

  defp page_title(:show), do: "Show Order"
  defp page_title(:edit), do: "Edit Order"
  defp page_title(:details), do: "Order Details"
  defp page_title(:items), do: "Order Items"

  defp order_trail(order, :items) do
    [
      Navigation.root(:orders),
      Navigation.resource(:order, order),
      Navigation.page(:orders, :order_items, order)
    ]
  end

  defp order_trail(order, _), do: [Navigation.root(:orders), Navigation.resource(:order, order)]
end
