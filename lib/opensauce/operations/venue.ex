defmodule OpenSauce.Operations.Venue do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "operations_venues"
    repo OpenSauce.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :address, :timezone, :type, :organisation_id],
      update: [:name, :address, :timezone, :type]
    ]
  end

  policies do
    policy always() do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :address, :string do
      public? true
    end

    attribute :timezone, :string do
      allow_nil? false
      public? true
      default "UTC"
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      default :kitchen
      constraints one_of: [:kitchen, :warehouse, :other]
    end

    timestamps()
  end

  relationships do
    has_many :storage_locations, OpenSauce.Operations.StorageLocation
    has_many :shifts, OpenSauce.Operations.Shift
  end
end
