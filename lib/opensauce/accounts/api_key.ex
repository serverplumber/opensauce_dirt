# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Accounts.ApiKey do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  alias OpenSauce.Accounts.ApiKey.Changes.GenerateKey

  postgres do
    table "accounts_api_keys"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :scopes]
      change {GenerateKey, []}
    end

    update :revoke do
      accept []
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    update :touch_last_used do
      accept []
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end

    read :list_for_organisation do
      prepare build(sort: [inserted_at: :desc])
    end

    read :authenticate do
      argument :key_hash, :string, allow_nil?: false
      get? true
      filter expr(key_hash == ^arg(:key_hash) and is_nil(revoked_at))
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass action(:authenticate) do
      authorize_if always()
    end

    bypass action(:touch_last_used) do
      authorize_if always()
    end

    policy always() do
      authorize_if expr(^actor(:role) == :owner)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :prefix, :string do
      allow_nil? false
      writable? false
    end

    attribute :key_hash, :string do
      allow_nil? false
      sensitive? true
      writable? false
    end

    attribute :scopes, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :last_used_at, :utc_datetime do
      allow_nil? true
      public? true
    end

    attribute :revoked_at, :utc_datetime do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  identities do
    identity :key_hash, [:key_hash]
  end
end
