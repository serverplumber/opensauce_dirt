defmodule OpenSauce.Accounts.OrganisationMember do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias OpenSauce.Accounts.OrganisationMember.Types.Role

  postgres do
    table "accounts_organisation_members"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:role, :display_title, :user_id, :organisation_id, :status], update: [:role, :display_title, :labor_hourly_rate]]

    update :suspend do
      accept []
      change set_attribute(:status, :suspended)
    end

    update :activate do
      accept []
      change set_attribute(:status, :active)
    end

    read :get_by_user_and_organisation do
      argument :user_id, :uuid, allow_nil?: false
      argument :organisation_id, :uuid, allow_nil?: false
      get? true
      filter expr(user_id == ^arg(:user_id) and organisation_id == ^arg(:organisation_id))
    end

    read :list_for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(load: [:organisation])
    end

    read :list_for_organisation do
      argument :organisation_id, :uuid, allow_nil?: false
      filter expr(organisation_id == ^arg(:organisation_id))
      prepare build(load: [:user])
    end
  end

  policies do
    # TODO: owners and managers can manage members; staff/readonly can read own membership
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, Role do
      allow_nil? false
      public? true
      default :staff
    end

    attribute :display_title, :string do
      allow_nil? true
      public? true
      constraints max_length: 100
    end

    attribute :labor_hourly_rate, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :status, :atom do
      public? true
      allow_nil? false
      default :active
      constraints one_of: [:active, :suspended]
    end

    timestamps()
  end

  relationships do
    belongs_to :user, OpenSauce.Accounts.User, allow_nil?: false, public?: true
    belongs_to :organisation, OpenSauce.Accounts.Organisation, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_membership, [:user_id, :organisation_id]
  end
end
