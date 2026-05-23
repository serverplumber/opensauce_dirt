defmodule OpenSauce.Orders.JobMaterial.Changes.MovePoItem do
  @moduledoc false
  use Ash.Resource.Change

  alias OpenSauce.Inventory

  @impl true
  def change(changeset, _opts, context) do
    old_job_id = changeset.data.job_id
    sci_id = changeset.data.supplier_catalog_item_id

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      new_job_id = record.job_id

      if old_job_id != new_job_id do
        open_items =
          Inventory.find_open_po_items_by_job_and_item!(
            old_job_id,
            sci_id,
            actor: context.actor,
            tenant: context.tenant
          )

        Enum.each(open_items, fn item ->
          Inventory.update_purchase_order_item!(
            item,
            %{job_id: new_job_id},
            actor: context.actor,
            tenant: context.tenant
          )
        end)
      end

      {:ok, record}
    end)
  end
end
