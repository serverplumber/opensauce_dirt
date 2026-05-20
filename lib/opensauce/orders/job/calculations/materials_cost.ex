defmodule OpenSauce.Orders.Job.Calculations.MaterialsCost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [materials: [:material]]

  @impl true
  def calculate(records, _opts, _context) do
    {:ok,
     Enum.map(records, fn job ->
       Enum.reduce(job.materials, Decimal.new(0), fn jm, acc ->
         price = (jm.material && jm.material.price) || Decimal.new(0)
         qty = jm.quantity || Decimal.new(0)
         Decimal.add(acc, Decimal.mult(qty, price))
       end)
     end)}
  end
end
