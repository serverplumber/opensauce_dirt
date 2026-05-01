defmodule OpenSauce.Operations.Shift do
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
    table "operations_shifts"
    repo OpenSauce.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:date, :venue_id, :member_id, :organisation_id],
      update: [:date, :venue_id, :member_id]
    ]
  end

  policies do
    policy always() do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :date, :date do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :member, OpenSauce.Accounts.OrganisationMember,
      domain: OpenSauce.Accounts,
      allow_nil?: false
  end
end
