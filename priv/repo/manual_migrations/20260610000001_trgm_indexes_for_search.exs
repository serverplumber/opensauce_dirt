defmodule OpenSauce.Repo.Migrations.TrgmIndexesForSearch do
  use Ecto.Migration

  def up do
    # Engagement title search
    execute """
    CREATE INDEX IF NOT EXISTS crm_engagements_scope_title_trgm_idx
      ON crm_engagements USING GIN (scope_title gin_trgm_ops)
    """

    # Customer name search
    execute """
    CREATE INDEX IF NOT EXISTS crm_customers_first_name_trgm_idx
      ON crm_customers USING GIN (first_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX IF NOT EXISTS crm_customers_last_name_trgm_idx
      ON crm_customers USING GIN (last_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX IF NOT EXISTS crm_customers_company_name_nickname_trgm_idx
      ON crm_customers USING GIN (company_name_nickname gin_trgm_ops)
    """

    # Garden/address name search
    execute """
    CREATE INDEX IF NOT EXISTS crm_addresses_name_trgm_idx
      ON crm_addresses USING GIN (name gin_trgm_ops)
    """

    # Supplier catalog items (referenced in code but indexes were missing)
    execute """
    CREATE INDEX IF NOT EXISTS inventory_supplier_catalog_items_latin_name_trgm_idx
      ON inventory_supplier_catalog_items USING GIN (latin_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX IF NOT EXISTS inventory_supplier_catalog_items_name_trgm_idx
      ON inventory_supplier_catalog_items USING GIN (name gin_trgm_ops)
    """

    execute """
    CREATE INDEX IF NOT EXISTS inventory_supplier_catalog_items_cultivar_trgm_idx
      ON inventory_supplier_catalog_items USING GIN (cultivar gin_trgm_ops)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS crm_engagements_scope_title_trgm_idx"
    execute "DROP INDEX IF EXISTS crm_customers_first_name_trgm_idx"
    execute "DROP INDEX IF EXISTS crm_customers_last_name_trgm_idx"
    execute "DROP INDEX IF EXISTS crm_customers_company_name_nickname_trgm_idx"
    execute "DROP INDEX IF EXISTS crm_addresses_name_trgm_idx"
    execute "DROP INDEX IF EXISTS inventory_supplier_catalog_items_latin_name_trgm_idx"
    execute "DROP INDEX IF EXISTS inventory_supplier_catalog_items_name_trgm_idx"
    execute "DROP INDEX IF EXISTS inventory_supplier_catalog_items_cultivar_trgm_idx"
  end
end
