defmodule OpenSauce.Repo.Migrations.AddPgTrgmCatalogueIndexes do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    execute """
    CREATE INDEX inventory_sci_latin_name_trgm_idx
      ON inventory_supplier_catalogue_items
      USING GIN (latin_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX inventory_sci_cultivar_trgm_idx
      ON inventory_supplier_catalogue_items
      USING GIN (cultivar gin_trgm_ops)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS inventory_sci_cultivar_trgm_idx"
    execute "DROP INDEX IF EXISTS inventory_sci_latin_name_trgm_idx"
    execute "DROP EXTENSION IF EXISTS pg_trgm"
  end
end
