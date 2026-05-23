defmodule OpenSauce.Inventory.SupplierCatalogItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "inventory_supplier_catalog_items"
    repo OpenSauce.Repo

    custom_indexes do
      index [:supplier_catalog_id], name: "inventory_sci_catalog_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [latin_name: :asc, cultivar: :asc, name: :asc])
    end

    # GIN trigram indexes on latin_name, cultivar, name back ILIKE with pg_trgm.
    read :search do
      argument :query, :string, allow_nil?: false
      argument :supplier_catalog_id, :uuid, allow_nil?: true
      argument :supplier_id, :uuid, allow_nil?: true

      filter expr(
               (is_nil(^arg(:supplier_catalog_id)) or
                  supplier_catalog_id == ^arg(:supplier_catalog_id)) and
                 (is_nil(^arg(:supplier_id)) or
                    supplier_catalog.supplier_id == ^arg(:supplier_id)) and
                 (fragment("? ILIKE '%' || ? || '%'", latin_name, ^arg(:query)) or
                    fragment("? ILIKE '%' || ? || '%'", cultivar, ^arg(:query)) or
                    fragment("? ILIKE '%' || ? || '%'", name, ^arg(:query)))
             )

      prepare build(sort: [latin_name: :asc, cultivar: :asc], limit: 50)
    end

    read :by_category do
      argument :category, :atom, allow_nil?: false
      filter expr(category == ^arg(:category))
      prepare build(sort: [latin_name: :asc, name: :asc])
    end

    create :create do
      primary? true

      accept [
        :supplier_catalog_id,
        :material_id,
        :sku,
        :name,
        :latin_name,
        :cultivar,
        :category,
        :format_description,
        :size_cm,
        :unit_price,
        :currency,
        :min_order_qty,
        :lead_time_days,
        :available,
        :notes
      ]
    end

    update :update do
      accept [
        :material_id,
        :sku,
        :name,
        :latin_name,
        :cultivar,
        :category,
        :format_description,
        :size_cm,
        :unit_price,
        :currency,
        :min_order_qty,
        :lead_time_days,
        :available,
        :notes
      ]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :sku, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :latin_name, :string do
      allow_nil? true
      public? true
    end

    attribute :cultivar, :string do
      allow_nil? true
      public? true
    end

    attribute :category, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:plant, :amendment, :container, :other]
    end

    # Verbatim from the supplier's catalog: "tige, 100mm WB", "Pots 1 gallon (3 L)", "30L bag", etc.
    attribute :format_description, :string do
      allow_nil? true
      public? true
      constraints max_length: 200
    end

    # For height-graded plants (cm). Distinct from pot format.
    attribute :size_cm, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :unit_price, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :currency, :atom do
      allow_nil? true
      public? true
      default :CAD
      constraints one_of: [:CAD, :USD, :EUR]
    end

    attribute :min_order_qty, :integer do
      allow_nil? false
      public? true
      default 1
      constraints min: 1
    end

    attribute :lead_time_days, :integer do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :available, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    belongs_to :supplier_catalog, OpenSauce.Inventory.SupplierCatalog do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :material, OpenSauce.Inventory.Material do
      allow_nil? true
      public? true
      attribute_writable? true
    end
  end
end
