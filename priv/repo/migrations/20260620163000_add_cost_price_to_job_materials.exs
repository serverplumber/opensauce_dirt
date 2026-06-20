defmodule OpenSauce.Repo.Migrations.AddCostPriceToJobMaterials do
  use Ecto.Migration

  def up do
    alter table(:orders_job_materials) do
      add :cost, :decimal, null: true
      add :price, :decimal, null: true
    end
  end

  def down do
    alter table(:orders_job_materials) do
      remove :cost
      remove :price
    end
  end
end
