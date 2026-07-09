# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

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

    update :update do
      accept [:first_name, :last_name, :email]
    end

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

    attribute :first_name, :string do
      public? true
      allow_nil? true
      constraints max_length: 100
    end

    attribute :last_name, :string do
      public? true
      allow_nil? true
      constraints max_length: 100
    end

    timestamps()
  end

  calculations do
    calculate :initials, :string, fn records, _ ->
      Enum.map(records, fn user ->
        cond do
          user.first_name && user.last_name ->
            String.upcase(String.first(user.first_name) <> String.first(user.last_name))

          user.first_name ->
            user.first_name
            |> String.split(~r/[\s\-]+/, trim: true)
            |> Enum.map(&String.first/1)
            |> Enum.take(2)
            |> Enum.join()
            |> String.upcase()

          true ->
            user.email
            |> to_string()
            |> String.split("@")
            |> hd()
            |> String.first()
            |> String.upcase()
        end
      end)
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
