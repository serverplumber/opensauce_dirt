defmodule OpenSauce.Inventory.Receiving do
  @moduledoc """
  Service for receiving purchase orders into stock.
  """

  alias Decimal, as: D
  alias OpenSauce.Inventory

  @doc """
  Finalizes a purchase order by creating stock movements for each item's
  received_qty (falling back to confirmed_qty, then quantity) and marking
  the PO as received.

  Items with zero effective qty or no linked material are skipped.
  Idempotent: if `received_at` is set, returns `{:ok, :already_received}`.
  """
  def receive_po(po_id, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    po =
      Inventory.get_purchase_order_by_id!(po_id,
        load: [items: [:quantity, :confirmed_qty, :received_qty, :material_id]],
        actor: actor,
        tenant: tenant
      )

    if po.received_at do
      {:ok, :already_received}
    else
      Enum.each(po.items, fn item ->
        effective_qty = item.received_qty || item.confirmed_qty || item.quantity

        if not is_nil(item.material_id) and D.compare(effective_qty, D.new(0)) == :gt do
          Inventory.adjust_stock(
            %{
              material_id: item.material_id,
              quantity: effective_qty,
              reason: "PO #{po.reference} received"
            },
            actor: actor,
            tenant: tenant
          )
        end
      end)

      Inventory.update_purchase_order(po, %{status: :received, received_at: DateTime.utc_now()},
        actor: actor,
        tenant: tenant
      )
    end
  end
end
