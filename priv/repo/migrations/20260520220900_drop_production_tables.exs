defmodule OpenSauce.Repo.Migrations.DropProductionTables do
  use Ecto.Migration

  def up do
    drop table(:orders_item_batch_allocations)
    drop table(:orders_item_lots)
    drop table(:orders_production_batch_lots)
    drop table(:orders_production_batches)
  end

  def down do
    # intentionally not reversible
  end
end
