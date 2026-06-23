# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.PurchasingLive.PurchaseOrderItemFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory
  alias OpenSauceWeb.CatalogSearchComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-direction:column;gap:16px;">
      <div>
        <p class="dark-label">Search Catalog</p>
        <.live_component
          module={CatalogSearchComponent}
          id={"po-item-catalog-search-#{@id}"}
          current_member={@current_member}
          notify={__MODULE__}
          notify_id={@id}
          selected_item={@selected_item}
        />
      </div>

      <.form
        for={@form}
        id="purchase-order-item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:12px;"
      >
        <input type="hidden" name={@form[:purchase_order_id].name} value={@form[:purchase_order_id].value} />
        <input
          type="hidden"
          name="purchase_order_item[supplier_catalog_item_id]"
          value={@selected_item && @selected_item.id}
        />

        <div style="display:flex;gap:10px;">
          <div style="flex:1;">
            <p class="dark-label">SKU</p>
            <input
              type="text"
              name="purchase_order_item[supplier_sku]"
              value={@sku_value}
              placeholder=""
              class="dark-input"
              style="width:100%;font-family:monospace;"
            />
          </div>
          <div style="flex:1;">
            <p class="dark-label">Unit cost</p>
            <input
              type="number"
              id={@form[:cost].id}
              name={@form[:cost].name}
              value={@price_value || @form[:cost].value}
              step="0.001"
              min="0"
              class="dark-input"
              style="width:100%;"
            />
          </div>
        </div>

        <div>
          <p class="dark-label">Quantity</p>
          <input
            type="number"
            id={@form[:quantity].id}
            name={@form[:quantity].name}
            value={@form[:quantity].value}
            step="1"
            min="1"
            class="dark-input"
            style="width:100%;"
          />
        </div>

        <div>
          <p class="dark-label">Material</p>
          <select
            id={@form[:material_id].id}
            name={@form[:material_id].name}
            class="dark-select"
            style={if is_nil(@form[:material_id].value) or @form[:material_id].value == "", do: "color:#6E675A;", else: "color:#F4EFE2;"}
          >
            <option value="">— none —</option>
            <option
              :for={m <- @materials}
              value={m.id}
              selected={@form[:material_id].value == m.id}
            >
              {m.name}
            </option>
          </select>
        </div>

        <input type="hidden" name={@form[:is_reservation].name} value={to_string(@is_reservation)} />
        <button
          type="button"
          phx-click="toggle_reservation"
          phx-target={@myself}
          ontouchstart=""
          style="display:flex;align-items:center;justify-content:space-between;width:100%;background:none;border:none;padding:0;cursor:pointer;"
        >
          <span style="font-size:13px;color:#9A9384;">Cherry-pick</span>
          <div style={"width:40px;height:24px;border-radius:999px;flex-shrink:0;transition:background 0.15s;position:relative;#{if @is_reservation, do: "background:#54B57E;", else: "background:#3A3528;"}"}>
            <div style={"width:18px;height:18px;border-radius:999px;background:#fff;position:absolute;top:3px;transition:left 0.15s;#{if @is_reservation, do: "left:19px;", else: "left:3px;"}"}></div>
          </div>
        </button>

        <button
          type="submit"
          phx-disable-with="Adding…"
          ontouchstart=""
          style="width:100%;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
        >
          Add Item
        </button>
      </.form>
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
       price_value: item.cost && Decimal.to_string(item.cost)
     )}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:selected_item, fn -> nil end)
      |> assign_new(:sku_value, fn -> "" end)
      |> assign_new(:price_value, fn -> nil end)
      |> assign_new(:is_reservation, fn ->
        case assigns[:purchase_order_item] do
          %{is_reservation: v} -> v
          _ -> false
        end
      end)
      |> assign_form()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_reservation", _params, socket) do
    {:noreply, assign(socket, :is_reservation, !socket.assigns.is_reservation)}
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
