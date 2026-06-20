defmodule OpenSauce.Repo.Migrations.AddPriceKindToSupplierCatalogs do
  use Ecto.Migration

  def up do
    alter table(:inventory_supplier_catalogs) do
      add :price_kind, :string, null: false, default: "msrp"
    end
  end

  def down do
    alter table(:inventory_supplier_catalogs) do
      remove :price_kind
    end
  end
end
