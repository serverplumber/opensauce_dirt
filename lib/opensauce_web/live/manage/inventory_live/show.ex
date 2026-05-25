defmodule OpenSauceWeb.InventoryLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:tabs_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@material.name}
      <:actions>
        <.link patch={~p"/manage/inventory/#{@material.sku}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit</.button>
        </.link>
        <.link patch={~p"/manage/inventory/#{@material.sku}/adjust"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Adjust Stock</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <.list>
          <:item title="Name">{@material.name}</:item>
          <:item title="SKU">
            <.kbd>
              {@material.sku}
            </.kbd>
          </:item>
          <:item title="Price">
            {format_money(@organisation.currency, @material.price)}
          </:item>
          <:item title="Current Stock">
            {format_amount(@material.unit, @material.current_stock)}
          </:item>
          <:item title="Minimum Stock">
            {format_amount(@material.unit, @material.minimum_stock)}
          </:item>
          <:item title="Maximum Stock">
            {format_amount(@material.unit, @material.maximum_stock)}
          </:item>
        </.list>

        <div :if={!Enum.empty?(@open_po_items)} class="mt-6">
          <div class="mb-2 text-base font-medium text-stone-900">Open Purchase Orders</div>
          <.table id="material-open-pos" rows={@open_po_items}>
            <:col :let={poi} label="Purchase Order">
              <.link navigate={~p"/manage/purchasing/#{poi.purchase_order.reference}"}>
                <.kbd>{poi.purchase_order.reference}</.kbd>
              </.link>
            </:col>
            <:col :let={poi} label="Supplier">
              <.link navigate={~p"/manage/purchasing/suppliers"} class="hover:underline">
                {poi.purchase_order.supplier.name}
              </.link>
            </:col>
            <:col :let={poi} label="Quantity">
              {format_amount(@material.unit, poi.quantity)}
            </:col>
            <:col :let={poi} label="Status">{poi.purchase_order.status}</:col>
          </.table>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :stock}>
        <div>
          <.table id="inventory_movements" no_margin rows={@material.movements}>
            <:empty>
              <div class="block py-4 pr-6">
                <span class={["relative"]}>
                  No movements found
                </span>
              </div>
            </:empty>

            <:col :let={entry} label="Date">
              {format_time(entry.inserted_at, @time_zone)}
            </:col>

            <:col :let={entry} label="Quantity">
              {format_amount(@material.unit, entry.quantity)}
            </:col>
            <:col :let={entry} label="Reason">{entry.reason}</:col>
          </.table>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="material-modal"
      title={@page_title}
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.sku}")}
    >
      <.live_component
        module={OpenSauceWeb.InventoryLive.FormComponentMaterial}
        id={@material.id}
        title={@page_title}
        action={@live_action}
        current_member={@current_member}
        material={@material}
        patch={~p"/manage/inventory/#{@material.sku}/details"}
      />
    </.modal>
    <.modal
      :if={@live_action == :adjust}
      title={"Adjust Stock for #{@material.name}"}
      id="material-movement-modal"
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.sku}")}
    >
      <.live_component
        module={OpenSauceWeb.InventoryLive.FormComponentMovement}
        id={@material.id}
        material={@material}
        current_member={@current_member}
        patch={~p"/manage/inventory/#{@material.sku}/stock"}
      />
    </.modal>
    """
  end

  @impl true
  def handle_params(%{"sku" => sku}, _, socket) do
    material =
      Inventory.get_material_by_sku!(sku,
        actor: socket.assigns.current_member,
        tenant: socket.assigns.current_member.organisation_id,
        load: [:current_stock, :movements]
      )

    open_po_items =
      Inventory.list_open_po_items_for_material!(
        %{material_id: material.id},
        actor: socket.assigns.current_member,
        tenant: socket.assigns.current_member.organisation_id
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/inventory/#{material.sku}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Stock",
        navigate: ~p"/manage/inventory/#{material.sku}/stock",
        active: live_action == :stock
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:material, material)
      |> assign(:open_po_items, open_po_items)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :inventory, material_trail(material, live_action))}
  end

  @impl true
  def handle_info({:saved, %Inventory.Movement{material_id: material_id}}, socket) do
    {:noreply, assign(socket, :material, reload_material(material_id, socket))}
  end

  @impl true
  def handle_info({:saved, %Inventory.Material{id: material_id}}, socket) do
    {:noreply, assign(socket, :material, reload_material(material_id, socket))}
  end

  defp reload_material(material_id, socket) do
    Inventory.get_material_by_id!(material_id,
      actor: socket.assigns.current_member,
      tenant: socket.assigns.current_member.organisation_id,
      load: [:current_stock, :movements]
    )
  end

  defp page_title(:show), do: "Show Material"
  defp page_title(:adjust), do: "Adjust Material"
  defp page_title(:edit), do: "Edit Material"
  defp page_title(:details), do: "Material Details"
  defp page_title(:stock), do: "Material Stock"

  defp material_trail(material, :stock) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_stock, material)
    ]
  end

  defp material_trail(material, _), do: [Navigation.root(:inventory), Navigation.resource(:material, material)]
end
