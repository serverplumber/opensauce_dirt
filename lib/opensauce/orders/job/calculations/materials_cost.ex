defmodule OpenSauce.Orders.Job.Calculations.MaterialsCost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(records, _opts, context) do
    actor = context.actor
    tenant = context.tenant

    records =
      Ash.load!(records, [materials: [supplier_catalog_item: []]], actor: actor, tenant: tenant)

    {:ok,
     Enum.map(records, fn job ->
       Enum.reduce(job.materials, Decimal.new(0), fn jm, acc ->
         price =
           (jm.supplier_catalog_item && jm.supplier_catalog_item.unit_price) || Decimal.new(0)

         qty = jm.quantity || Decimal.new(0)
         Decimal.add(acc, Decimal.mult(qty, price))
       end)
     end)}
  end
end
