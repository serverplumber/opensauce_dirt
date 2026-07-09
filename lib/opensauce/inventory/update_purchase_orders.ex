defmodule OpenSauce.Inventory.UpdatePurchaseOrders do
  @moduledoc false

  alias Decimal, as: D
  alias OpenSauce.Inventory
  alias OpenSauce.Work

  # Delivery and installation jobs for the same garden list the same physical
  # plants — the delivery drops them, the installation puts them in the ground.
  # We take the max quantity across the pair rather than summing.
  @paired_categories [:delivery, :installation]

  @doc """
  Ensures upcoming scheduled jobs have draft PO items for all catalog-linked
  materials. Groups items by supplier and appends to (or creates) one draft
  PO per supplier.

  Delivery + installation jobs at the same garden are rolled up: the max
  quantity across the pair is used since they refer to the same plants.
  All other service categories contribute independently.

  Quantities are rounded up to each catalog item's minimum order quantity.

  Returns {:ok, n} where n is the number of new PO items created.
  """
  def run(opts) do
    actor = Keyword.fetch!(opts, :actor)
    tenant = Keyword.fetch!(opts, :tenant)

    jobs =
      Work.list_upcoming_jobs!(
        actor: actor,
        tenant: tenant,
        load: [materials: [supplier_catalog_item: [:supplier_catalog]]]
      )

    open_items =
      Inventory.list_open_purchase_order_items!(actor: actor, tenant: tenant)

    covered =
      open_items
      |> Enum.filter(&(!is_nil(&1.job_id) && !is_nil(&1.supplier_catalog_item_id)))
      |> MapSet.new(&{&1.job_id, &1.supplier_catalog_item_id})

    {paired_jobs, other_jobs} =
      Enum.split_with(jobs, &(&1.service_category in @paired_categories))

    uncovered =
      (build_paired_needs(paired_jobs, covered) ++ build_other_needs(other_jobs, covered))
      |> Enum.reject(&is_nil(&1.supplier_id))
      |> Enum.map(&Map.put(&1, :quantity, apply_min_order_qty(&1.quantity, &1.sci)))

    if uncovered == [] do
      {:ok, 0}
    else
      draft_pos = Inventory.list_draft_purchase_orders!(actor: actor, tenant: tenant)
      draft_by_supplier = Map.new(draft_pos, &{&1.supplier_id, &1})

      uncovered
      |> Enum.group_by(& &1.supplier_id)
      |> Enum.each(fn {supplier_id, items} ->
        po =
          Map.get_lazy(draft_by_supplier, supplier_id, fn ->
            Inventory.create_purchase_order!(%{supplier_id: supplier_id},
              actor: actor,
              tenant: tenant
            )
          end)

        Enum.each(items, fn item ->
          Inventory.create_purchase_order_item!(
            %{
              purchase_order_id: po.id,
              job_id: item.job_id,
              supplier_catalog_item_id: item.sci_id,
              supplier_sku: item.sci.sku,
              quantity: item.quantity,
              cost: item.sci.unit_price
            },
            actor: actor,
            tenant: tenant
          )
        end)
      end)

      {:ok, length(uncovered)}
    end
  end

  # Delivery + installation at the same garden share the same physical plants.
  # Group by (garden_id, sci_id), take max quantity across the group.
  # The group is covered if any job in it already has an open PO item for the sci.
  defp build_paired_needs(jobs, covered) do
    jobs
    |> Enum.flat_map(fn job ->
      Enum.map(job.materials, fn jm ->
        %{
          job_id: job.id,
          garden_id: job.garden_id,
          sci_id: jm.supplier_catalog_item_id,
          sci: jm.supplier_catalog_item,
          quantity: jm.quantity
        }
      end)
    end)
    |> Enum.filter(&(!is_nil(&1.sci_id) && D.gt?(&1.quantity, D.new(0))))
    |> Enum.group_by(&{&1.garden_id, &1.sci_id})
    |> Enum.map(fn {{_garden_id, sci_id}, group} ->
      max_qty =
        Enum.reduce(group, D.new(0), fn item, acc ->
          if D.gt?(item.quantity, acc), do: item.quantity, else: acc
        end)

      all_job_ids = MapSet.new(group, & &1.job_id)
      sci = hd(group).sci

      %{
        job_id: hd(group).job_id,
        sci_id: sci_id,
        sci: sci,
        supplier_id: supplier_id(sci),
        quantity: max_qty,
        all_job_ids: all_job_ids
      }
    end)
    |> Enum.reject(fn item ->
      Enum.any?(item.all_job_ids, &MapSet.member?(covered, {&1, item.sci_id}))
    end)
  end

  # All other service categories: each job's material needs are independent.
  defp build_other_needs(jobs, covered) do
    jobs
    |> Enum.flat_map(fn job ->
      Enum.map(job.materials, fn jm ->
        %{
          job_id: job.id,
          sci_id: jm.supplier_catalog_item_id,
          sci: jm.supplier_catalog_item,
          quantity: jm.quantity,
          supplier_id: supplier_id(jm.supplier_catalog_item)
        }
      end)
    end)
    |> Enum.filter(&(!is_nil(&1.sci_id) && D.gt?(&1.quantity, D.new(0))))
    |> Enum.reject(&MapSet.member?(covered, {&1.job_id, &1.sci_id}))
  end

  defp supplier_id(%{supplier_catalog: %{supplier_id: id}}) when not is_nil(id), do: id
  defp supplier_id(_), do: nil

  # Round up to the nearest multiple of min_order_qty.
  defp apply_min_order_qty(quantity, %{min_order_qty: min_qty}) when min_qty > 1 do
    min_d = D.new(min_qty)
    D.mult(D.round(D.div(quantity, min_d), 0, :ceiling), min_d)
  end

  defp apply_min_order_qty(quantity, _), do: quantity
end
