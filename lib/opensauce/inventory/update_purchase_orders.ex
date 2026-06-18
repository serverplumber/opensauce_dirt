defmodule OpenSauce.Inventory.UpdatePurchaseOrders do
  @moduledoc false

  alias OpenSauce.{Inventory, Orders}

  @doc """
  Ensures every upcoming scheduled job has PO items for all its required
  catalog items. Groups items by supplier and appends to (or creates) one
  draft PO per supplier.

  Returns {:ok, n} where n is the number of new PO items added.
  """
  def run(opts) do
    actor = Keyword.fetch!(opts, :actor)
    tenant = Keyword.fetch!(opts, :tenant)

    jobs =
      Orders.list_upcoming_jobs!(
        actor: actor,
        tenant: tenant,
        load: [materials: [supplier_catalog_item: [:supplier_catalog]]]
      )

    open_items =
      Inventory.list_open_purchase_order_items!(
        actor: actor,
        tenant: tenant
      )

    covered =
      open_items
      |> Enum.filter(&(!is_nil(&1.job_id) && !is_nil(&1.supplier_catalog_item_id)))
      |> MapSet.new(&{&1.job_id, &1.supplier_catalog_item_id})

    uncovered =
      for job <- jobs,
          jm <- job.materials,
          sci = jm.supplier_catalog_item,
          not is_nil(sci),
          not MapSet.member?(covered, {job.id, sci.id}),
          do: %{
            job_id: job.id,
            supplier_id: sci.supplier_catalog && sci.supplier_catalog.supplier_id,
            supplier_catalog_item_id: sci.id,
            supplier_sku: sci.sku,
            quantity: jm.quantity,
            unit_price: sci.unit_price
          }

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
            Inventory.create_purchase_order!(%{supplier_id: supplier_id}, actor: actor, tenant: tenant)
          end)

        Enum.each(items, fn item ->
          Inventory.create_purchase_order_item!(
            item |> Map.put(:purchase_order_id, po.id) |> Map.delete(:supplier_id),
            actor: actor,
            tenant: tenant
          )
        end)
      end)

      {:ok, length(uncovered)}
    end
  end
end
