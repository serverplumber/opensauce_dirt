defmodule OpenSauce.Repo.Migrations.AddCostPriceToEngagementMaterials do
  use Ecto.Migration

  def up do
    alter table(:crm_engagement_materials) do
      add :cost, :decimal, null: true
      add :price, :decimal, null: true
    end
  end

  def down do
    alter table(:crm_engagement_materials) do
      remove :cost
      remove :price
    end
  end
end
