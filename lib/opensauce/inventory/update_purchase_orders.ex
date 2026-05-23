defmodule OpenSauce.Inventory.UpdatePurchaseOrders do
  @moduledoc false

  alias OpenSauce.{Inventory, Orders}

  @doc """
  Ensures every upcoming scheduled job has PO items for all its required
  catalog items. Appends missing items to an existing draft PO, or creates
  a new draft PO if none exists.

  Returns {:ok, n} where n is the number of new PO items added.
  """
  def run(opts) do
    actor = Keyword.fetch!(opts, :actor)
    tenant = Keyword.fetch!(opts, :tenant)

    jobs =
      Orders.list_upcoming_jobs!(
        actor: actor,
        tenant: tenant,
        load: [materials: [:supplier_catalog_item]]
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
            supplier_catalog_item_id: sci.id,
            supplier_sku: sci.sku,
            quantity: jm.quantity,
            unit_price: sci.unit_price
          }

    if uncovered == [] do
      {:ok, 0}
    else
      draft_po =
        case Inventory.list_draft_purchase_orders!(actor: actor, tenant: tenant) do
          [po | _] ->
            po

          [] ->
            Inventory.create_purchase_order!(%{}, actor: actor, tenant: tenant)
        end

      Enum.each(uncovered, fn item ->
        Inventory.create_purchase_order_item!(
          Map.put(item, :purchase_order_id, draft_po.id),
          actor: actor,
          tenant: tenant
        )
      end)

      {:ok, length(uncovered)}
    end
  end
end
