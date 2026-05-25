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
      create: [:name, :address, :organisation_id],
      update: [:name, :address]
    ]
  end

  policies do
    policy always() do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
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

    timestamps()
  end

  relationships do
    has_many :storage_locations, OpenSauce.Operations.StorageLocation
  end
end
