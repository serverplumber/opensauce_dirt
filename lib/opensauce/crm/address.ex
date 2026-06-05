defmodule OpenSauce.CRM.Address do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "crm_addresses"
    repo OpenSauce.Repo
  end

  actions do
    default_accept :*
    defaults [:read, :create, :update, :destroy]

    read :list_gardens do
      filter expr(is_garden == true)
      prepare build(sort: [name: :asc])
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? true
      public? true
    end

    attribute :is_billing, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :is_garden, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :is_indoor, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :street, :string do
      allow_nil? true
      public? true
    end

    attribute :city, :string do
      allow_nil? true
      public? true
    end

    attribute :province, :string do
      allow_nil? true
      public? true
    end

    attribute :zip, :string do
      allow_nil? true
      public? true
    end

    attribute :country, :string do
      allow_nil? true
      public? true
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
    end

    # TODO(polish): geocoding
    #   - populate `location` from street/city/zip via Mapbox or Nominatim
    #   - decide: sync change in a create/update action, or async via Oban?
    #   - migration: use `geography(Point, 4326)` (metres, round-Earth) not
    #     `geometry` (degrees, planar) — we want correct distances between
    #     job sites for routing
    #   - add GiST index on location when populated
    #   - swap :map stub below for a proper Geo.PostGIS type once PostGIS is wired up
    attribute :location, :map do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :customer, OpenSauce.CRM.Customer do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    belongs_to :organisation, OpenSauce.Accounts.Organisation do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.Accounts
    end

    belongs_to :supplier, OpenSauce.Inventory.Supplier do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.Inventory
    end
  end

  calculations do
    calculate :full_address, :string, fn records, _ ->
      Enum.map(records, fn addr ->
        [addr.street, addr.city, addr.province, addr.zip, addr.country]
        |> Enum.reject(&(is_nil(&1) or &1 == ""))
        |> case do
          [] -> nil
          parts -> Enum.join(parts, ", ")
        end
      end)
    end

    calculate :short_address, :string, fn records, _ ->
      Enum.map(records, fn addr ->
        [addr.street, addr.city, addr.zip]
        |> Enum.reject(&(is_nil(&1) or &1 == ""))
        |> case do
          [] -> nil
          parts -> Enum.join(parts, ", ")
        end
      end)
    end
  end
end
