defmodule OpenSauce.Inventory.SupplierCatalogueItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "inventory_supplier_catalogue_items"
    repo OpenSauce.Repo

    custom_indexes do
      # Standard btree indexes for exact lookups
      index [:latin_name], name: "inventory_sci_latin_name_index"
      index [:cultivar], name: "inventory_sci_cultivar_index"
      index [:supplier_catalogue_id], name: "inventory_sci_catalogue_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [latin_name: :asc, cultivar: :asc, name: :asc])
    end

    # Primary search path: Latin name → cultivar → common name, case-insensitive
    # GIN trigram indexes on latin_name and cultivar (see migration add_pg_trgm)
    # make this fast across large supplier catalogues.
    read :search do
      argument :query, :string, allow_nil?: false

      filter expr(
               contains(string_downcase(latin_name), string_downcase(^arg(:query))) or
                 contains(string_downcase(cultivar), string_downcase(^arg(:query))) or
                 contains(string_downcase(name), string_downcase(^arg(:query)))
             )

      prepare build(sort: [latin_name: :asc, cultivar: :asc])
    end

    read :by_category do
      argument :category, :atom, allow_nil?: false
      filter expr(category == ^arg(:category))
      prepare build(sort: [latin_name: :asc, name: :asc])
    end

    create :create do
      primary? true

      accept [
        :supplier_catalogue_id,
        :material_id,
        :sku,
        :name,
        :latin_name,
        :cultivar,
        :category,
        :format,
        :size_cm,
        :volume,
        :volume_unit,
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
        :format,
        :size_cm,
        :volume,
        :volume_unit,
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

    # Plants: [plant_number][format_letter] e.g. "12345B". Non-plants: arbitrary.
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

    # :bare_root — size_cm is height
    # :potted    — size_cm is pot/root-ball diameter, volume is pot volume
    # :volume    — volume + volume_unit only (amendments, soil)
    # :unit      — sold as discrete units, no size (e.g. trays, bags by count)
    attribute :format, :atom do
      allow_nil? true
      public? true
      constraints one_of: [:bare_root, :potted, :volume, :unit]
    end

    attribute :size_cm, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :volume, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :volume_unit, :atom do
      allow_nil? true
      public? true
      constraints one_of: [:liter, :gallon, :cubic_foot]
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
    belongs_to :supplier_catalogue, OpenSauce.Inventory.SupplierCatalogue do
      allow_nil? false
      public? true
    end

    belongs_to :material, OpenSauce.Inventory.Material do
      allow_nil? true
      public? true
      attribute_writable? true
    end
  end
end
