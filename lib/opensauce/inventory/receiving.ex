# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.Receiving do
  @moduledoc """
  Turns a confirmed purchase order into stock, once the crew has picked it
  up and logged what actually came back.
  """

  alias Decimal, as: D
  alias OpenSauce.Inventory

  @doc """
  Marks a purchase order received and moves each line item into stock.

  Per item, the quantity actually recorded wins: `received_qty` if it was
  set at pickup, otherwise the supplier's `confirmed_qty`, otherwise the
  original `quantity` on the line. Lines with no linked material yet, or a
  non-positive effective quantity, don't touch stock — they stay as PO
  lines only.

  Safe to call twice: once `received_at` is set, this is a no-op that
  returns `{:ok, :already_received}` instead of double-booking stock.
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
      for item <- po.items, do: receive_item(item, po, actor, tenant)

      Inventory.update_purchase_order(po, %{status: :received, received_at: DateTime.utc_now()},
        actor: actor,
        tenant: tenant
      )
    end
  end

  defp receive_item(item, po, actor, tenant) do
    qty = item.received_qty || item.confirmed_qty || item.quantity

    if item.material_id && D.compare(qty, D.new(0)) == :gt do
      Inventory.adjust_stock(
        %{material_id: item.material_id, quantity: qty, reason: "PO #{po.reference} received"},
        actor: actor,
        tenant: tenant
      )
    end
  end
end
