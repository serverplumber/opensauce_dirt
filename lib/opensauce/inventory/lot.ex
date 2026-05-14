defmodule OpenSauce.Inventory.Lot do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted, OpenSauce.Concerns.Venued]

  json_api do
    type "lot"

    routes do
      base("/lots")
      get(:read)
      index :read
    end
  end

  graphql do
    type :lot

    queries do
      get(:get_lot, :read)
      list(:list_lots, :read)
    end
  end

  postgres do
    table "inventory_lots"
    repo OpenSauce.Repo

    custom_indexes do
      index [:lot_code], unique: true, name: "inventory_lots_lot_code_index"
      index [:material_id], name: "inventory_lots_material_id_index"
      index [:supplier_id], name: "inventory_lots_supplier_id_index"
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:lot_code, :expiry_date, :received_at, :material_id, :supplier_id, :venue_id],
      update: [:lot_code, :expiry_date, :received_at, :supplier_id, :venue_id]
    ]

    read :available_for_material do
      argument :material_id, :uuid, allow_nil?: false
      filter expr(material_id == ^arg(:material_id) and current_stock > 0)
      prepare build(load: [:current_stock], sort: [expiry_date: :asc])
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {OpenSauce.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :lot_code, :string do
      allow_nil? false
    end

    attribute :expiry_date, :date do
      allow_nil? true
    end

    attribute :received_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :material, OpenSauce.Inventory.Material do
      allow_nil? false
    end

    belongs_to :supplier, OpenSauce.Inventory.Supplier do
      allow_nil? true
    end

    has_many :movements, OpenSauce.Inventory.Movement
  end

  aggregates do
    sum :current_stock, :movements, :quantity
  end
end
