# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Accounts.TaxRate do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted],
    primary_read_warning?: false

  postgres do
    table "accounts_tax_rates"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      primary? true
      prepare build(sort: [position: :asc, inserted_at: :asc])
    end

    create :create do
      primary? true
      accept [:name, :rate, :is_compound, :position, :registration_number]
    end

    update :update do
      primary? true
      accept [:name, :rate, :is_compound, :position, :registration_number]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 1
    end

    attribute :rate, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    # When true, applied to (base price + sum of all prior non-compound taxes)
    attribute :is_compound, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :position, :integer do
      public? true
      allow_nil? false
      default 0
    end

    attribute :registration_number, :string do
      public? true
      allow_nil? true
    end

    timestamps()
  end
end
