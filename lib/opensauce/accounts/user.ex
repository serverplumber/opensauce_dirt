defmodule OpenSauce.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    tokens do
      enabled? true
      token_resource OpenSauce.Accounts.Token
      signing_secret OpenSauce.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        sender OpenSauce.Accounts.User.Senders.SendMagicLink
        require_interaction? true
        # Users are created via the setup/invite flow, not self-registration.
        registration_enabled? false
      end
    end
  end

  postgres do
    table "accounts_users"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, create: [:email]]

    read :get_by_subject do
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_email, [:email]
  end
end
