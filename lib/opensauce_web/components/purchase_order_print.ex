defmodule OpenSauceWeb.PurchaseOrderPrint do
  @moduledoc false
  use OpenSauceWeb, :html

  alias Decimal, as: D

  @doc """
  Renders a print-only PO layout. Hidden on screen, visible when printing.

  Assigns:
    - `po`           — PurchaseOrder with items loaded (items: [:material, supplier_catalog_item: [], job: [:garden]])
    - `currency`     — atom, e.g. :CAD
    - `organisation` — Organisation with :address loaded
  """
  attr :po, :map, required: true
  attr :currency, :atom, required: true
  attr :organisation, :map, required: true
  attr :org_address, :map, default: nil
  attr :rep, :string, default: nil
  attr :mode, :atom, required: true

  def purchase_order_print(assigns) do
    ~H"""
    <div class="hidden p-8 text-sm text-stone-800 print:block">
      <%!-- Rollup sheet: supplier totals --%>
      <div :if={@mode == :rollup}>
        <div class="mb-6 border-b border-stone-300 pb-4">
          <div class="mb-3 flex items-baseline justify-between">
            <div class="text-xs text-stone-400">
              {@po.reference}
              <span class="mx-1">·</span>
              {Phoenix.Naming.humanize(@po.status)}
              <span :if={@po.ordered_at}>
                <span class="mx-1">·</span>Ordered {fmt_date(@po.ordered_at)}
              </span>
            </div>
            <div class="text-[10px] font-semibold uppercase tracking-wider text-stone-400">
              Supply run — totals
            </div>
          </div>

          <div class="grid grid-cols-2 gap-8">
            <div>
              <div class="text-[10px] mb-1 font-semibold uppercase tracking-wider text-stone-400">
                Purchasing party
              </div>
              <div class="text-base font-bold text-stone-900">{@organisation.name}</div>
              <div :if={@organisation.legal_name} class="text-xs text-stone-500">
                {@organisation.legal_name}
              </div>
              <div :if={@rep} class="mt-0.5 text-xs text-stone-500">
                Rep: <span class="font-medium text-stone-700">{@rep}</span>
              </div>
              <div :if={@org_address} class="mt-0.5 text-xs text-stone-500">
                <div :if={@org_address.street}>{@org_address.street}</div>
                <div :if={addr_city_line(@org_address) != ""}>{addr_city_line(@org_address)}</div>
              </div>
            </div>
            <div>
              <div class="text-[10px] mb-1 font-semibold uppercase tracking-wider text-stone-400">
                Supplier
              </div>
              <div class="text-base font-bold text-stone-900">
                {(@po.supplier && @po.supplier.name) || "—"}
              </div>
              <div
                :if={@po.supplier && supplier_primary_address(@po.supplier)}
                class="mt-0.5 text-xs text-stone-500"
              >
                <% addr = supplier_primary_address(@po.supplier) %>
                <div :if={addr.street}>{addr.street}</div>
                <div :if={addr_city_line(addr) != ""}>{addr_city_line(addr)}</div>
              </div>
            </div>
          </div>
        </div>

        <% rollup = rollup_rows(@po.items) %>
        <table class="w-full border-collapse">
          <thead>
            <tr class="border-b border-stone-300 text-left text-xs font-semibold uppercase tracking-wide text-stone-500">
              <th class="pr-4 pb-2">SKU</th>
              <th class="pr-4 pb-2">Item</th>
              <th class="pr-4 pb-2">Format</th>
              <th class="pr-4 pb-2 text-right">Total qty</th>
              <th class="pb-2 text-right">Unit price</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- rollup} class="border-b border-stone-100">
              <td class="font-mono py-2 pr-4">{row.supplier_sku}</td>
              <td class="py-2 pr-4 italic">{item_label(row)}</td>
              <td class="py-2 pr-4 text-stone-500">
                {(row.supplier_catalog_item && row.supplier_catalog_item.format_description) || ""}
              </td>
              <td class="py-2 pr-4 text-right font-semibold">{fmt_qty(row.quantity)}</td>
              <td class="py-2 text-right">
                {if row.cost, do: format_money(@currency, row.cost), else: "—"}
              </td>
            </tr>
          </tbody>
        </table>

        <div class="mt-4 flex justify-end border-t border-stone-200 pt-3 text-xs text-stone-500">
          <span class="mr-3">Lines: {length(rollup)}</span>
          <span>
            Est. cost:
            <span class="font-medium text-stone-800">
              {format_money(@currency, subtotal(@po.items))}
            </span>
          </span>
        </div>

        <div class="mt-10 flex gap-16 text-xs text-stone-400">
          <span>Picked by: ___________________________</span>
          <span>Date: _______________</span>
        </div>
      </div>

      <%!-- Per-site sheets --%>
      <div :if={@mode == :sheets}>
        <%!-- Single header: picking up from supplier --%>
        <div class="mb-6 border-b border-stone-300 pb-4">
          <div class="mb-3 text-xs text-stone-400">
            {@po.reference}
            <span class="mx-1">·</span>
            {Phoenix.Naming.humanize(@po.status)}
            <span :if={@po.ordered_at}>
              <span class="mx-1">·</span>Ordered {fmt_date(@po.ordered_at)}
            </span>
          </div>
          <div class="flex items-baseline justify-between">
            <div>
              <div class="text-[10px] mb-1 font-semibold uppercase tracking-wider text-stone-400">
                Picking up from
              </div>
              <div class="text-xl font-bold text-stone-900">
                {(@po.supplier && @po.supplier.name) || "—"}
              </div>
              <div
                :if={@po.supplier && supplier_primary_address(@po.supplier)}
                class="mt-0.5 text-xs text-stone-500"
              >
                <% addr = supplier_primary_address(@po.supplier) %>
                <div :if={addr.street}>{addr.street}</div>
                <div :if={addr_city_line(addr) != ""}>{addr_city_line(addr)}</div>
              </div>
            </div>
            <div class="text-right">
              <div class="text-sm font-bold text-stone-900">{@organisation.name}</div>
              <div :if={@rep} class="text-xs text-stone-500">{@rep}</div>
            </div>
          </div>
        </div>

        <%!-- One section per garden, HR-style --%>
        <div :for={{garden, items} <- print_groups(@po.items)} class="mt-6">
          <div class="mb-3 border-t-2 border-stone-400 pt-3">
            <div class="text-sm font-bold text-stone-900">
              {garden_section_label(garden, items)}
            </div>
            <div :if={garden && garden.street} class="mt-0.5 text-xs text-stone-400">
              {garden.street}<span :if={addr_city_line(garden) != ""}>, {addr_city_line(garden)}</span>
            </div>
          </div>

          <table class="w-full border-collapse">
            <thead>
              <tr class="border-b border-stone-300 text-left text-xs font-semibold uppercase tracking-wide text-stone-500">
                <th class="pr-4 pb-1">SKU</th>
                <th class="pr-4 pb-1">Plant</th>
                <th class="pr-4 pb-1">Format</th>
                <th class="pr-4 pb-1 text-right">Ordered</th>
                <th class="pb-1 text-right">Confirmed</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- items} class="border-b border-stone-100">
                <td class="font-mono py-1.5 pr-4 text-xs">{item.supplier_sku}</td>
                <td class="py-1.5 pr-4 italic">{item_label(item)}</td>
                <td class="py-1.5 pr-4 text-stone-500">
                  {(item.supplier_catalog_item && item.supplier_catalog_item.format_description) || ""}
                </td>
                <td class="py-1.5 pr-4 text-right font-semibold">{fmt_qty(item.quantity)}</td>
                <td class="py-1.5 text-right">
                  <span :if={item.confirmed_qty}>{fmt_qty(item.confirmed_qty)}</span>
                  <span :if={!item.confirmed_qty} class="inline-block w-16 border-b border-stone-400">
                    &nbsp;
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="mt-10 flex gap-16 text-xs text-stone-400">
          <span>Picked by: ___________________________</span>
          <span>Date: _______________</span>
        </div>
      </div>
    </div>
    """
  end

  # Collapses all items to unique SKUs/catalog entries with summed quantities.
  defp rollup_rows(items) do
    items
    |> Enum.group_by(fn item ->
      (item.supplier_catalog_item && item.supplier_catalog_item.id) || item.supplier_sku
    end)
    |> Enum.map(fn {_key, group} ->
      total =
        Enum.reduce(group, D.new(0), fn item, acc -> D.add(acc, item.quantity || D.new(0)) end)

      %{List.first(group) | quantity: total}
    end)
    |> Enum.sort_by(&item_label/1)
  end

  # Groups items by garden (address) for per-garden sheets.
  # Multiple jobs at the same address appear on one page.
  # Returns {address | nil, items}; nil means no address grouping (single sheet).
  defp print_groups(items) do
    with_address = Enum.filter(items, fn item -> item.job && item.job.garden_id end)

    if with_address == [] do
      [{nil, items}]
    else
      items
      |> Enum.group_by(fn item -> item.job && item.job.garden_id end)
      |> Enum.map(fn {_garden_id, group} ->
        address = Enum.find_value(group, fn item -> item.job && item.job.garden end)
        {address, group}
      end)
      |> Enum.sort_by(fn {address, _} -> garden_sort_key(address) end)
    end
  end

  defp garden_sort_key(nil), do: ""
  defp garden_sort_key(%{name: name}) when not is_nil(name), do: name

  defp garden_sort_key(%{city: city, street: street}) when not is_nil(city), do: "#{city}#{street}"

  defp garden_sort_key(_), do: ""

  defp addr_city_line(address) do
    [address.city, address.province, address.zip]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp fmt_date(dt), do: Calendar.strftime(dt, "%b %-d, %Y")

  defp subtotal(items) do
    Enum.reduce(items, D.new(0), fn item, acc ->
      price = item.cost || D.new(0)
      qty = item.quantity || D.new(0)
      D.add(acc, D.mult(qty, price))
    end)
  end

  defp item_label(%{supplier_catalog_item: %{latin_name: ln, cultivar: cv}}) when not is_nil(ln),
    do: [ln, cv] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

  defp item_label(%{material: %{name: name}}) when not is_nil(name), do: name
  defp item_label(_), do: "—"

  defp fmt_qty(nil), do: nil
  defp fmt_qty(%D{} = d), do: D.to_string(d)
  defp fmt_qty(n), do: to_string(n)

  defp supplier_primary_address(%{addresses: [addr | _]}), do: addr
  defp supplier_primary_address(_), do: nil

  defp garden_section_label(nil, _items), do: "Unassigned"

  defp garden_section_label(garden, items) do
    client = garden.customer && customer_short(garden.customer)
    garden_name = garden.name
    engagement = Enum.find_value(items, fn item -> item.job && item.job.engagement end)
    engagement_title = engagement && engagement.scope_title

    [client, garden_name, engagement_title]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(" — ")
    |> case do
      "" -> "—"
      label -> label
    end
  end

  defp customer_short(%{company_name_nickname: cn}) when not is_nil(cn), do: cn

  defp customer_short(%{first_name: fn_, last_name: ln}) do
    [fn_, ln] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp customer_short(_), do: "—"
end
