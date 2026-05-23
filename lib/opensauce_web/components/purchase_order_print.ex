defmodule OpenSauceWeb.PurchaseOrderPrint do
  @moduledoc false
  use OpenSauceWeb, :html

  alias Decimal, as: D

  @doc """
  Renders a print-only PO layout. Hidden on screen, visible when printing.

  Assigns:
    - `po`           — PurchaseOrder with items loaded (items: [supplier_catalog_item, job: [:address]])
    - `currency`     — atom, e.g. :CAD
    - `organisation` — Organisation with :address loaded
  """
  attr :po, :map, required: true
  attr :currency, :atom, required: true
  attr :organisation, :map, required: true

  def purchase_order_print(assigns) do
    ~H"""
    <div class="hidden print:block p-8 text-sm text-stone-800">
      <div
        :for={{garden, items} <- print_groups(@po.items)}
        class="break-after-page last:break-after-auto"
      >
        <div class="mb-6 border-b border-stone-300 pb-4">
          <div class="mb-3 text-xs text-stone-400">
            {@po.reference}
            <span class="mx-1">·</span>
            {Phoenix.Naming.humanize(@po.status)}
            <span :if={@po.ordered_at}>
              <span class="mx-1">·</span>Ordered {fmt_date(@po.ordered_at)}
            </span>
          </div>

          <div class="grid grid-cols-2 gap-8">
            <div>
              <div class="mb-1 text-[10px] font-semibold uppercase tracking-wider text-stone-400">
                Purchasing party
              </div>
              <div class="text-base font-bold text-stone-900">{@organisation.name}</div>
              <div :if={@organisation.address} class="mt-0.5 text-xs text-stone-500">
                <div :if={@organisation.address.street}>{@organisation.address.street}</div>
                <div :if={addr_city_line(@organisation.address) != ""}>
                  {addr_city_line(@organisation.address)}
                </div>
              </div>
            </div>
            <div>
              <div class="mb-1 text-[10px] font-semibold uppercase tracking-wider text-stone-400">
                Supplier
              </div>
              <div class="text-base font-bold text-stone-900">
                {(@po.supplier && @po.supplier.name) || "—"}
              </div>
              <div :if={@po.supplier && @po.supplier.address} class="mt-0.5 text-xs text-stone-500">
                <div :if={@po.supplier.address.street}>{@po.supplier.address.street}</div>
                <div :if={addr_city_line(@po.supplier.address) != ""}>
                  {addr_city_line(@po.supplier.address)}
                </div>
              </div>
            </div>
          </div>

          <div :if={garden} class="mt-4 border-t border-stone-100 pt-3 text-xs">
            <div class="mb-1 text-[10px] font-semibold uppercase tracking-wider text-stone-400">
              Delivery to
            </div>
            <div :if={garden.name} class="font-medium text-stone-800">{garden.name}</div>
            <div class="mt-0.5 text-stone-500">
              <div :if={garden.street}>{garden.street}</div>
              <div :if={addr_city_line(garden) != ""}>{addr_city_line(garden)}</div>
            </div>
          </div>
        </div>

        <table class="w-full border-collapse">
          <thead>
            <tr class="border-b border-stone-300 text-left text-xs font-semibold uppercase tracking-wide text-stone-500">
              <th class="pb-2 pr-4">SKU</th>
              <th class="pb-2 pr-4">Plant</th>
              <th class="pb-2 pr-4">Format</th>
              <th class="pb-2 pr-4 text-right">Ordered</th>
              <th class="pb-2 pr-4 text-right">Confirmed</th>
              <th class="pb-2 text-right">Unit Price</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={item <- items} class="border-b border-stone-100">
              <td class="py-2 pr-4 font-mono">{item.supplier_sku}</td>
              <td class="py-2 pr-4 italic">{item_label(item)}</td>
              <td class="py-2 pr-4 text-stone-500">
                {(item.supplier_catalog_item && item.supplier_catalog_item.format_description) || ""}
              </td>
              <td class="py-2 pr-4 text-right">{fmt_qty(item.quantity)}</td>
              <td class="py-2 pr-4 text-right">{fmt_qty(item.confirmed_qty) || "—"}</td>
              <td class="py-2 text-right">
                {if item.unit_price, do: format_money(@currency, item.unit_price), else: "—"}
              </td>
            </tr>
          </tbody>
        </table>

        <div class="mt-4 flex justify-end border-t border-stone-200 pt-3 text-xs text-stone-500">
          <span class="mr-3">Total lines: {length(items)}</span>
          <span>
            Est. cost:
            <span class="font-medium text-stone-800">
              {format_money(@currency, subtotal(items))}
            </span>
          </span>
        </div>

        <div class="mt-10 flex gap-16 text-xs text-stone-400">
          <span>Picked by: ___________________________</span>
          <span>Date: _______________</span>
        </div>
      </div>
    </div>
    """
  end

  # Groups items by garden (address) for per-garden sheets.
  # Multiple jobs at the same address appear on one page.
  # Returns {address | nil, items}; nil means no address grouping (single sheet).
  defp print_groups(items) do
    with_address = Enum.filter(items, fn item -> item.job && item.job.address_id end)

    if with_address == [] do
      [{nil, items}]
    else
      items
      |> Enum.group_by(fn item -> item.job && item.job.address_id end)
      |> Enum.map(fn {_address_id, group} ->
        address = Enum.find_value(group, fn item -> item.job && item.job.address end)
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
      price = item.unit_price || D.new(0)
      qty = item.quantity || D.new(0)
      D.add(acc, D.mult(qty, price))
    end)
  end

  defp item_label(%{supplier_catalog_item: %{latin_name: ln, cultivar: cv}})
       when not is_nil(ln),
       do: [ln, cv] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

  defp item_label(%{material: %{name: name}}) when not is_nil(name), do: name
  defp item_label(_), do: "—"

  defp fmt_qty(nil), do: nil
  defp fmt_qty(%D{} = d), do: D.to_string(d)
  defp fmt_qty(n), do: to_string(n)
end
