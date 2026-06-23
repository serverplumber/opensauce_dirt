defmodule OpenSauceWeb.CatalogSearchComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Inventory

  # Assigns (required):
  #   current_member  — actor for Ash calls
  #   notify          — parent LiveComponent module (e.g. __MODULE__)
  #   notify_id       — parent LiveComponent id
  # Assigns (optional):
  #   selected_item   — pre-selected SupplierCatalogItem (controlled from outside, e.g. to clear)

  @impl true
  def render(assigns) do
    ~H"""
    <div style="position:relative;">
      <form phx-change="search" phx-target={@myself}>
        <input
          type="text"
          value={@search_query}
          phx-debounce="300"
          name="catalog_search"
          placeholder="Latin name, cultivar, or common name…"
          autocomplete="off"
          class="dark-input"
          style="width:100%;"
        />
      </form>

      <div
        :if={@search_results != []}
        style="position:absolute;z-index:20;margin-top:4px;width:100%;background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:12px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.5);"
      >
        <button
          :for={item <- @search_results}
          type="button"
          phx-click="pick"
          phx-value-id={item.id}
          phx-target={@myself}
          ontouchstart=""
          style="display:flex;flex-direction:column;width:100%;padding:10px 12px;text-align:left;background:none;border:none;border-bottom:1px solid rgba(52,48,37,0.4);cursor:pointer;last-child:border-bottom:none;"
        >
          <div style="display:flex;align-items:baseline;justify-content:space-between;gap:8px;width:100%;">
            <span style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
              {catalog_item_title(item)}
            </span>
            <span style="font-size:11px;color:#6E675A;flex-shrink:0;">
              {item.supplier_catalog.supplier.name}
            </span>
          </div>
          <span style="font-size:11px;color:#9A9384;margin-top:2px;">
            {item.name}
            {if item.format_description, do: " · #{item.format_description}"}
            {if item.sku, do: " · #{item.sku}"}
          </span>
        </button>
      </div>

      <div
        :if={@selected_item}
        style="margin-top:8px;background:#211E16;border-radius:12px;border:1.5px solid #54B57E;padding:10px 12px;display:flex;align-items:flex-start;justify-content:space-between;gap:8px;"
      >
        <div style="min-width:0;flex:1;">
          <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {catalog_item_title(@selected_item)}
          </p>
          <p style="font-size:11px;color:#9A9384;margin-top:2px;">
            {@selected_item.supplier_catalog.supplier.name}
            {if @selected_item.format_description,
              do: " · #{@selected_item.format_description}"}
          </p>
        </div>
        <button
          type="button"
          phx-click="clear"
          phx-target={@myself}
          ontouchstart=""
          style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;flex-shrink:0;"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path
              d="M18 6L6 18M6 6l12 12"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="round"
            />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:search_query, fn -> "" end)
     |> assign_new(:search_results, fn -> [] end)
     |> assign_new(:selected_item, fn -> nil end)}
  end

  @impl true
  def handle_event("search", %{"catalog_search" => query}, socket) do
    query = String.trim(query)
    member = socket.assigns.current_member

    results =
      if String.length(query) >= 2 do
        Inventory.search_supplier_catalog_items!(query,
          actor: member,
          tenant: member.organisation_id,
          load: [supplier_catalog: [:supplier]]
        )
      else
        []
      end

    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  @impl true
  def handle_event("pick", %{"id" => id}, socket) do
    member = socket.assigns.current_member

    item =
      Ash.get!(Inventory.SupplierCatalogItem, id,
        actor: member,
        tenant: member.organisation_id,
        load: [supplier_catalog: [:supplier]]
      )

    send_update(socket.assigns.notify, id: socket.assigns.notify_id, catalog_item: item)

    {:noreply, assign(socket, selected_item: item, search_query: "", search_results: [])}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    send_update(socket.assigns.notify, id: socket.assigns.notify_id, catalog_item: nil)
    {:noreply, assign(socket, selected_item: nil, search_query: "", search_results: [])}
  end

  defp catalog_item_title(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name
      title -> title
    end
  end
end
