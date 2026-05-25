defmodule OpenSauce.Orders.Job.Calculations.RealizedCost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:duration, :mileage_km, :materials_cost]

  @impl true
  def calculate(records, _opts, context) do
    overhead = load_overhead(context)
    members_by_user_id = load_members(context)

    {:ok,
     Enum.map(records, fn job ->
       member = job.actor_id && Map.get(members_by_user_id, job.actor_id)
       labor = labor_cost(job.duration, member, overhead)
       mileage = mileage_cost(job.mileage_km)
       materials = job.materials_cost || Decimal.new(0)

       Decimal.add(labor, Decimal.add(mileage, materials))
     end)}
  end

  defp labor_cost(nil, _member, _overhead), do: Decimal.new(0)
  defp labor_cost(_minutes, nil, _overhead), do: Decimal.new(0)

  defp labor_cost(minutes, member, overhead) do
    rate = member.labor_hourly_rate || Decimal.new(0)
    hours = Decimal.div(Decimal.new(minutes), Decimal.new(60))
    multiplier = Decimal.add(Decimal.new(1), overhead)
    rate |> Decimal.mult(hours) |> Decimal.mult(multiplier)
  end

  defp mileage_cost(nil), do: Decimal.new(0)
  defp mileage_cost(_km), do: Decimal.new(0)

  defp load_overhead(context) do
    case Ash.get(OpenSauce.Accounts.Organisation, context.tenant, authorize?: false) do
      {:ok, org} -> org.labor_overhead_percent || Decimal.new(0)
      _ -> Decimal.new(0)
    end
  end

  defp load_members(context) do
    case OpenSauce.Accounts.list_members_for_organisation(context.tenant, authorize?: false) do
      {:ok, members} -> Map.new(members, &{&1.user_id, &1})
      _ -> %{}
    end
  end
end
