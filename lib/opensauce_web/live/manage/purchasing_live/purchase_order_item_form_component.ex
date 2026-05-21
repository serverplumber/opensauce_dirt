defmodule OpenSauceWeb.PurchasingLive.PurchaseOrderItemFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Catalogue search --%>
      <div class="mb-4">
        <label class="mb-1 block text-sm font-medium text-stone-700">
          Search Catalogue
        </label>
        <div class="relative">
          <input
            type="text"
            value={@search_query}
            phx-change="search"
            phx-debounce="300"
            phx-target={@myself}
            name="catalogue_search"
            placeholder="Latin name, cultivar, or common name…"
            autocomplete="off"
            class="w-full rounded border border-stone-300 px-3 py-2 text-sm focus:border-primary-400 focus:outline-none"
          />
          <div
            :if={@search_results != []}
            class="absolute z-10 mt-1 w-full rounded-md border border-stone-200 bg-white shadow-lg"
          >
            <button
              :for={item <- @search_results}
              type="button"
              phx-click="pick_item"
              phx-value-id={item.id}
              phx-target={@myself}
              class="flex w-full flex-col px-3 py-2 text-left text-sm hover:bg-stone-50"
            >
              <span class="font-medium italic text-stone-700">
                {[item.latin_name, item.cultivar] |> Enum.reject(&is_nil/1) |> Enum.join(" ")}
              </span>
              <span class="text-xs text-stone-400">
                {item.name}
                {if item.format_description, do: "· #{item.format_description}"}
                {if item.sku, do: "· #{item.sku}"}
              </span>
            </button>
          </div>
        </div>
      </div>

      <%!-- Selected item chip --%>
      <div :if={@selected_item} class="mb-4 flex items-center justify-between rounded-md bg-primary-50 border border-primary-200 px-3 py-2">
        <div class="text-sm">
          <span class="font-medium italic text-primary-800">
            {[
              @selected_item.latin_name,
              @selected_item.cultivar
            ]
            |> Enum.reject(&is_nil/1)
            |> Enum.join(" ")}
          </span>
          <span class="ml-2 text-primary-600">{@selected_item.name}</span>
          <span :if={@selected_item.format_description} class="ml-2 text-primary-500">
            {@selected_item.format_description}
          </span>
        </div>
        <button type="button" phx-click="clear_item" phx-target={@myself} class="ml-2 text-primary-400 hover:text-primary-600">
          <.icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      </div>

      <.simple_form
        for={@form}
        id="purchase-order-item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:purchase_order_id]} type="hidden" />
        <input type="hidden" name="purchase_order_item[supplier_catalogue_item_id]" value={@selected_item && @selected_item.id} />

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="mb-1 block text-sm font-medium text-stone-700">SKU</label>
            <input
              type="text"
              name="purchase_order_item[supplier_sku]"
              value={@sku_value}
              placeholder="From catalogue or enter manually"
              class="w-full rounded border border-stone-300 px-3 py-2 text-sm font-mono focus:border-primary-400 focus:outline-none"
            />
          </div>
          <.input field={@form[:unit_price]} type="number" label="Unit Price" step="0.001" min="0" value={@price_value} />
        </div>

        <.input field={@form[:quantity]} type="number" label="Quantity" step="1" min="1" />

        <.input
          field={@form[:material_id]}
          type="select"
          label="Material (optional — link to stock)"
          options={[{"— none —", nil}] ++ for(m <- @materials, do: {m.name, m.id})}
        />

        <.input field={@form[:is_reservation]} type="checkbox" label="Cherry-pick (inspect individually)" />

        <:actions>
          <.button variant={:primary} phx-disable-with="Adding...">Add Item</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_query, fn -> "" end)
      |> assign_new(:search_results, fn -> [] end)
      |> assign_new(:selected_item, fn -> nil end)
      |> assign_new(:sku_value, fn -> "" end)
      |> assign_new(:price_value, fn -> nil end)
      |> assign_form()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"catalogue_search" => query}, socket) do
    query = String.trim(query)

    results =
      if String.length(query) >= 2 do
        member = socket.assigns.current_member
        supplier_id = socket.assigns.supplier && socket.assigns.supplier.id

        Inventory.search_supplier_catalogue_items(query,
          supplier_id: supplier_id,
          actor: member,
          tenant: member.organisation_id
        )
      else
        []
      end

    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  @impl true
  def handle_event("pick_item", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    item = Ash.get!(Inventory.SupplierCatalogueItem, id, opts)

    price_value = item.unit_price && Decimal.to_string(item.unit_price)

    socket =
      assign(socket,
        selected_item: item,
        sku_value: item.sku || "",
        price_value: price_value,
        search_query: "",
        search_results: []
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_item", _params, socket) do
    {:noreply, assign(socket, selected_item: nil, sku_value: "", price_value: nil, search_query: "", search_results: [])}
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
