defmodule OpenSauce.Orders.Job.Calculations.EstimatedCost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:man_hour_rate, :materials_cost]

  @impl true
  def calculate(records, _opts, context) do
    overhead = load_overhead(context)

    {:ok,
     Enum.map(records, fn job ->
       with estimate when not is_nil(estimate) <- job.duration_estimate,
            rate when not is_nil(rate) <- job.man_hour_rate,
            true <- Decimal.gt?(rate, Decimal.new(0)) do
         hours = Decimal.div(Decimal.new(estimate), Decimal.new(60))
         multiplier = Decimal.add(Decimal.new(1), overhead)
         labor = hours |> Decimal.mult(rate) |> Decimal.mult(multiplier)
         materials = job.materials_cost || Decimal.new(0)
         Decimal.add(labor, materials)
       else
         _ -> nil
       end
     end)}
  end

  defp load_overhead(context) do
    case Ash.get(OpenSauce.Accounts.Organisation, context.tenant, authorize?: false) do
      {:ok, org} -> org.labor_overhead_percent || Decimal.new(0)
      _ -> Decimal.new(0)
    end
  end
end
