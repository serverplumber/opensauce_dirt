defmodule OpenSauce.Orders.Job.Calculations.MileageKm do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:events]

  @impl true
  def calculate(records, _opts, _context) do
    {:ok,
     Enum.map(records, fn job ->
       {open_tag, close_tag} =
         if job.type == :shift,
           do: {:shift_start, :shift_end},
           else: {:arrival, :departure}

       job.events
       |> Enum.sort_by(& &1.timestamp, DateTime)
       |> odometer_diff(open_tag, close_tag)
     end)}
  end

  defp odometer_diff(events, open_tag, close_tag) do
    start_reading =
      Enum.find(events, fn e -> e.data.type == open_tag end)

    end_reading =
      Enum.find(events, fn e -> e.data.type == close_tag end)

    case {start_reading, end_reading} do
      {%{data: %{value: %{odometer_km: s}}}, %{data: %{value: %{odometer_km: e}}}}
      when not is_nil(s) and not is_nil(e) ->
        Decimal.sub(e, s)

      _ ->
        nil
    end
  end
end
