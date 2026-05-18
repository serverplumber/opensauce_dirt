defmodule OpenSauce.Orders.Job.Calculations.ActualDurationMinutes do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:events]

  @impl true
  def calculate(records, _opts, _context) do
    {:ok,
     Enum.map(records, fn job ->
       job.events
       |> Enum.sort_by(& &1.timestamp, DateTime)
       |> sum_paired_minutes()
     end)}
  end

  # Walk events chronologically. Each arrival opens a pair; the next departure
  # closes it and accumulates elapsed minutes. Work session events and orphan
  # departures are ignored.
  defp sum_paired_minutes(events) do
    {total, _open} =
      Enum.reduce(events, {0, nil}, fn
        %{data: %Ash.Union{type: :arrival}} = e, {acc, _} ->
          {acc, e}

        %{data: %Ash.Union{type: :departure}} = e, {acc, open} when open != nil ->
          minutes = DateTime.diff(e.timestamp, open.timestamp, :second) |> div(60)
          {acc + minutes, nil}

        _other, state ->
          state
      end)

    if total > 0, do: total, else: nil
  end
end
