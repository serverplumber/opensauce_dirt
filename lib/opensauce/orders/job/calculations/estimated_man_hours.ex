defmodule OpenSauce.Orders.Job.Calculations.EstimatedManHours do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def calculate(records, _opts, _context) do
    {:ok,
     Enum.map(records, fn job ->
       if job.duration_estimate do
         Decimal.div(Decimal.new(job.duration_estimate), Decimal.new(60))
       end
     end)}
  end
end
