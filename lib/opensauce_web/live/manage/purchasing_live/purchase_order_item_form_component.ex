defmodule OpenSauceWeb.PurchasingLive.PurchaseOrderItemFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory
  alias OpenSauceWeb.CatalogSearchComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-4">
        <label class="mb-1 block text-sm font-medium text-stone-700">Search Catalog</label>
        <.live_component
          module={CatalogSearchComponent}
          id={"po-item-catalog-search-#{@id}"}
          current_member={@current_member}
          notify={__MODULE__}
          notify_id={@id}
          selected_item={@selected_item}
        />
      </div>

      <.simple_form
        for={@form}
        id="purchase-order-item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:purchase_order_id]} type="hidden" />
        <input
          type="hidden"
          name="purchase_order_item[supplier_catalog_item_id]"
          value={@selected_item && @selected_item.id}
        />

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="mb-1 block text-sm font-medium text-stone-700">SKU</label>
            <input
              type="text"
              name="purchase_order_item[supplier_sku]"
              value={@sku_value}
              placeholder="From catalog or enter manually"
              class="w-full rounded border border-stone-300 px-3 py-2 text-sm font-mono focus:border-primary-400 focus:outline-none"
            />
          </div>
          <.input
            field={@form[:unit_price]}
            type="number"
            label="Unit Price"
            step="0.001"
            min="0"
            value={@price_value}
          />
        </div>

        <.input field={@form[:quantity]} type="number" label="Quantity" step="1" min="1" />

        <.input
          field={@form[:material_id]}
          type="select"
          label="Material (optional — link to stock)"
          options={[{"— none —", nil}] ++ for(m <- @materials, do: {m.name, m.id})}
        />

        <.input
          field={@form[:is_reservation]}
          type="checkbox"
          label="Cherry-pick (inspect individually)"
        />

        <:actions>
          <.button variant={:primary} phx-disable-with="Adding...">Add Item</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{catalog_item: nil} = _assigns, socket) do
    {:ok, assign(socket, selected_item: nil, sku_value: "", price_value: nil)}
  end

  def update(%{catalog_item: item} = _assigns, socket) do
    {:ok,
     assign(socket,
       selected_item: item,
       sku_value: item.sku || "",
       price_value: item.unit_price && Decimal.to_string(item.unit_price)
     )}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:selected_item, fn -> nil end)
      |> assign_new(:sku_value, fn -> "" end)
      |> assign_new(:price_value, fn -> nil end)
      |> assign_form()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"purchase_order_item" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"purchase_order_item" => params}, socket) do
    params =
      params
      |> Map.put_new("supplier_sku", socket.assigns.sku_value)
      |> Map.update("supplier_sku", socket.assigns.sku_value, fn v ->
        if v == "", do: socket.assigns.sku_value, else: v
      end)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, item} ->
        send(self(), {:po_item_saved, item})
        {:noreply, socket |> put_flash(:info, "Item added") |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{purchase_order_item: item, po_id: po_id}} = socket) do
    form =
      if item do
        Form.for_update(item, :update,
          as: "purchase_order_item",
          actor: socket.assigns.current_member,
          tenant: socket.assigns.current_member.organisation_id
        )
      else
        Form.for_create(Inventory.PurchaseOrderItem, :create,
          as: "purchase_order_item",
          actor: socket.assigns.current_member,
          tenant: socket.assigns.current_member.organisation_id,
          params: %{purchase_order_id: po_id}
        )
      end

    assign(socket, form: to_form(form))
  end
end
