defmodule OpenSauce.Work.Job.Calculations.Duration do
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
       |> sum_paired_minutes(open_tag, close_tag)
     end)}
  end

  defp sum_paired_minutes(events, open_tag, close_tag) do
    {total, _open} =
      Enum.reduce(events, {0, nil}, fn
        %{data: %Ash.Union{type: ^open_tag}} = e, {acc, _} ->
          {acc, e}

        %{data: %Ash.Union{type: ^close_tag}} = e, {acc, open} when open != nil ->
          minutes = e.timestamp |> DateTime.diff(open.timestamp, :second) |> div(60)
          {acc + minutes, nil}

        _other, state ->
          state
      end)

    if total > 0, do: total
  end
end
