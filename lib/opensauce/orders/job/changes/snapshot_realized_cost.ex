defmodule OpenSauce.Orders.Job.Changes.SnapshotRealizedCost do
  @moduledoc """
  Computes and stores realized cost when a job is marked complete. Will sum JobEvents to realize
  Job costs, which will include JobEvents which are punch in and outs of crew who were there for
  only parts of the job.
  """
  use Ash.Resource.Change

  alias OpenSauce.Orders.JobEvent

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, job ->
      tenant = changeset.tenant

      with {:ok, events} <- load_events(job.id, tenant),
           {:ok, org} <- Ash.get(OpenSauce.Accounts.Organisation, tenant, authorize?: false),
           {:ok, loaded_job} <- Ash.load(job, [:mileage_km, :materials_cost],
                                  authorize?: false, tenant: tenant) do
        overhead = org.labor_overhead_percent || Decimal.new(0)
        mileage_rate = org.mileage_cost_per_km || Decimal.new(0)

        labor = compute_labor(events, job.type, overhead)
        mileage = Decimal.mult(loaded_job.mileage_km || Decimal.new(0), mileage_rate)
        materials = loaded_job.materials_cost || Decimal.new(0)

        realized = Decimal.add(labor, Decimal.add(mileage, materials))

        job
        |> Ash.Changeset.for_update(:write_realized_cost, %{realized_cost: realized})
        |> Ash.update(authorize?: false, tenant: tenant)
      else
        _ -> {:ok, job}
      end
    end)
  end

  defp load_events(job_id, tenant) do
    Ash.read(JobEvent,
      action: :for_job,
      arguments: %{job_id: job_id},
      load: [event_staff: []],
      authorize?: false,
      tenant: tenant
    )
  end

  defp compute_labor(events, type, overhead) do
    {open_tag, close_tag} =
      if type == :shift, do: {:shift_start, :shift_end}, else: {:arrival, :departure}

    sorted = Enum.sort_by(events, & &1.timestamp, DateTime)

    {total, _open} =
      Enum.reduce(sorted, {Decimal.new(0), nil}, fn
        %{data: %Ash.Union{type: ^open_tag}} = e, {acc, _} ->
          {acc, e}

        %{data: %Ash.Union{type: ^close_tag}} = e, {acc, open} when open != nil ->
          minutes = DateTime.diff(e.timestamp, open.timestamp, :second) |> div(60)
          hours = Decimal.div(Decimal.new(minutes), Decimal.new(60))
          rate = sum_staff_rates(open.event_staff)
          multiplier = Decimal.add(Decimal.new(1), overhead)
          pair_cost = hours |> Decimal.mult(rate) |> Decimal.mult(multiplier)
          {Decimal.add(acc, pair_cost), nil}

        _other, state ->
          state
      end)

    total
  end

  defp sum_staff_rates(event_staff) do
    Enum.reduce(event_staff || [], Decimal.new(0), fn s, acc ->
      Decimal.add(acc, s.man_hour_rate || Decimal.new(0))
    end)
  end
end
