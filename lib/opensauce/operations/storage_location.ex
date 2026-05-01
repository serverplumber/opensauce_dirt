defmodule OpenSauce.Operations.StorageLocation do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      OpenSauce.Concerns.Multitenanted,
      OpenSauce.Concerns.Venued,
    ]

  postgres do
    table "operations_storage_locations"
    repo OpenSauce.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :venue_id, :organisation_id],
      update: [:name]
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

    timestamps()
  end
end
