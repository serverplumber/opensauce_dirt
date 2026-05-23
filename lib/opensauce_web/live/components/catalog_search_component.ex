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
    <div>
      <div class="relative">
        <form phx-change="search" phx-target={@myself}>
          <input
            type="text"
            value={@search_query}
            phx-debounce="300"
            name="catalog_search"
            placeholder="Latin name, cultivar, or common name…"
            autocomplete="off"
            class="w-full rounded border border-stone-300 px-3 py-2 text-sm focus:border-primary-400 focus:outline-none"
          />
        </form>
        <div
          :if={@search_results != []}
          class="absolute z-10 mt-1 w-full rounded-md border border-stone-200 bg-white shadow-lg"
        >
          <button
            :for={item <- @search_results}
            type="button"
            phx-click="pick"
            phx-value-id={item.id}
            phx-target={@myself}
            class="flex w-full flex-col px-3 py-2 text-left text-sm hover:bg-stone-50"
          >
            <div class="flex w-full items-baseline justify-between gap-2">
              <span class="font-medium italic text-stone-700">{catalog_item_title(item)}</span>
              <span class="shrink-0 text-xs font-medium text-stone-400">
                {item.supplier_catalog.supplier.name}
              </span>
            </div>
            <span class="text-xs text-stone-400">
              {item.name}
              {if item.format_description, do: "· #{item.format_description}"}
              {if item.sku, do: "· #{item.sku}"}
            </span>
          </button>
        </div>
      </div>

      <div
        :if={@selected_item}
        class="mt-2 flex items-center justify-between rounded-md border border-primary-200 bg-primary-50 px-3 py-2"
      >
        <div class="text-sm">
          <span class="font-medium italic text-primary-800">
            {catalog_item_title(@selected_item)}
          </span>
          <span class="ml-2 text-primary-600">{@selected_item.name}</span>
          <span :if={@selected_item.format_description} class="ml-2 text-primary-500">
            {@selected_item.format_description}
          </span>
          <span class="ml-2 text-xs font-medium text-primary-400">
            {@selected_item.supplier_catalog.supplier.name}
          </span>
        </div>
        <button
          type="button"
          phx-click="clear"
          phx-target={@myself}
          class="ml-2 text-primary-400 hover:text-primary-600"
        >
          <.icon name="hero-x-mark" class="h-4 w-4" />
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
