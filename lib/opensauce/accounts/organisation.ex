defmodule OpenSauce.Accounts.Organisation do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "accounts_organisations"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:name, :slug], update: [:name]]
  end

  policies do
    # TODO: tighten once session/auth flow is finalised
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :members, OpenSauce.Accounts.OrganisationMember
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
