defmodule OpenSauceWeb.PurchasingLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory
  alias OpenSauce.Inventory.Receiving
  alias OpenSauce.Inventory.UpdatePurchaseOrders
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      Purchasing
      <:actions>
        <.button phx-click="update_purchase_orders" phx-disable-with="Checking…">
          Update from Jobs
        </.button>
        <.link patch={~p"/manage/purchasing/new"}>
          <.button variant={:primary}>New Purchase Order</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.table
        id="purchase-orders"
        rows={@purchase_orders}
        row_click={fn po -> JS.navigate(~p"/manage/purchasing/#{po.reference}") end}
      >
        <:col :let={po} label="Reference">
          <.kbd>{po.reference}</.kbd>
        </:col>
        <:col :let={po} label="Supplier">{(po.supplier && po.supplier.name) || "—"}</:col>
        <:col :let={po} label="Status">{po.status}</:col>
        <:col :let={po} label="Ordered">{format_time(po.ordered_at, @time_zone)}</:col>
        <:col :let={po} label="Received">{format_time(po.received_at, @time_zone)}</:col>

        <:action :let={po}>
          <.link :if={po.status != :received} phx-click={JS.push("receive", value: %{id: po.id})}>
            <.button size={:sm}>Mark Received</.button>
          </.link>
        </:action>
      </.table>
    </div>

    <.modal
      :if={@live_action == :new}
      id="po-new-modal"
      show
      title="New Purchase Order"
      on_cancel={JS.patch(~p"/manage/purchasing")}
    >
      <.live_component
        module={OpenSauceWeb.PurchasingLive.PurchaseOrderFormComponent}
        id="po-form"
        current_member={@current_member}
        suppliers={@suppliers}
        purchase_order={nil}
        patch={~p"/manage/purchasing"}
      />
    </.modal>

    <.modal
      :if={@live_action == :add_item}
      id="po-item-modal"
      show
      title={"Add Item to #{if @selected_po, do: @selected_po.reference, else: "PO"}"}
      on_cancel={JS.patch(~p"/manage/purchasing")}
    >
      <.live_component
        module={OpenSauceWeb.PurchasingLive.PurchaseOrderItemFormComponent}
        id="po-item-form"
        current_member={@current_member}
        materials={@materials}
        po_id={@selected_po && @selected_po.id}
        purchase_order_item={nil}
        patch={~p"/manage/purchasing"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    suppliers = Inventory.list_suppliers!(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id)
    materials = Inventory.list_materials!(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id)
    pos = load_purchase_orders(socket)

    {:ok,
     assign(socket,
       suppliers: suppliers,
       materials: materials,
       purchase_orders: pos,
       selected_po: nil,
       purchasing_tab: :purchase_orders
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :page_title, "Purchase Orders")

    socket =
      case socket.assigns.live_action do
        :add_item ->
          po =
            Inventory.get_purchase_order_by_reference!(params["po_ref"],
              load: [:supplier],
              actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id
            )

          assign(socket, :selected_po, po)

        _ ->
          assign(socket, :selected_po, nil)
      end

    {:noreply, Navigation.assign(socket, :purchasing, purchasing_trail(socket.assigns))}
  end

  @impl true
  def handle_event("update_purchase_orders", _params, socket) do
    member = socket.assigns.current_member

    case UpdatePurchaseOrders.run(actor: member, tenant: member.organisation_id) do
      {:ok, 0} ->
        {:noreply, put_flash(socket, :info, "All job materials are already on open POs.")}

      {:ok, n} ->
        {:noreply,
         socket
         |> assign(:purchase_orders, load_purchase_orders(socket))
         |> put_flash(:info, "Added #{n} item(s) to the draft PO.")}
    end
  end

  @impl true
  def handle_event("receive", %{"id" => id}, socket) do
    _ = Receiving.receive_po(id, actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id)
    {:noreply, assign(socket, :purchase_orders, load_purchase_orders(socket))}
  end

  @impl true
  def handle_info({:po_saved, _po}, socket) do
    {:noreply,
     socket
     |> assign(:purchase_orders, load_purchase_orders(socket))
     |> put_flash(:info, "Purchase order created")
     |> push_event("close-modal", %{id: "po-new-modal"})}
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Item added to PO")
     |> push_event("close-modal", %{id: "po-item-modal"})}
  end

  defp purchasing_trail(%{live_action: :new}),
    do: [Navigation.root(:purchasing), Navigation.page(:purchasing, :new_purchase_order)]

  defp purchasing_trail(%{live_action: :add_item, selected_po: %{} = po}),
    do: [Navigation.root(:purchasing), Navigation.resource(:purchase_order, po)]

  defp purchasing_trail(_), do: [Navigation.root(:purchasing)]

  defp load_purchase_orders(socket) do
    Inventory.list_purchase_orders!(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id, load: [:supplier])
  end
end
