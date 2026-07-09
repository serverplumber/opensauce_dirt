defmodule OpenSauce.Work.Job.Calculations.ManHourRate do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [staff_assignments: [:member]]

  @impl true
  def calculate(records, _opts, _context) do
    {:ok,
     Enum.map(records, fn job ->
       Enum.reduce(job.staff_assignments || [], Decimal.new(0), fn assignment, acc ->
         rate = (assignment.member && assignment.member.labor_hourly_rate) || Decimal.new(0)
         Decimal.add(acc, rate)
       end)
     end)}
  end
end
