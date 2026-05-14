defmodule OpenSauce.Inventory.SupplierCatalogue do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "inventory_supplier_catalogues"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [year: :desc, name: :asc])
    end

    create :create do
      primary? true
      accept [:name, :supplier_id, :season, :year, :valid_from, :valid_until]
    end

    update :update do
      accept [:name, :season, :year, :valid_from, :valid_until]
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

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :season, :atom do
      allow_nil? false
      public? true
      default :year_round
      constraints one_of: [:spring, :fall, :year_round]
    end

    attribute :year, :integer do
      allow_nil? false
      public? true
    end

    attribute :valid_from, :date do
      allow_nil? true
      public? true
    end

    attribute :valid_until, :date do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :supplier, OpenSauce.Inventory.Supplier do
      allow_nil? false
      public? true
    end

    has_many :items, OpenSauce.Inventory.SupplierCatalogueItem
  end
end
