# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.Supplier do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]

  json_api do
    type "supplier"

    routes do
      base("/suppliers")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :supplier

    queries do
      get(:get_supplier, :read)
      list(:list_suppliers, :list)
    end

    mutations do
      create :create_supplier, :create
      update :update_supplier, :update
    end
  end

  postgres do
    table "inventory_suppliers"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [name: :asc])
    end

    create :create do
      primary? true
      accept [:name, :contact_name, :contact_email, :contact_phone, :notes]

      argument :addresses, {:array, :map}, allow_nil?: true, default: []

      change manage_relationship(:addresses,
               on_lookup: :relate,
               on_no_match: :create,
               on_match: :update,
               on_missing: :destroy
             )
    end

    update :update do
      accept [:name, :contact_name, :contact_email, :contact_phone, :notes]

      argument :addresses, {:array, :map}, allow_nil?: true, default: []

      change manage_relationship(:addresses,
               on_lookup: :relate,
               on_no_match: :create,
               on_match: :update,
               on_missing: :destroy
             )
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {OpenSauce.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}\w\s\-\.・（）「」]+$/u
    end

    attribute :contact_name, :string do
      allow_nil? true
      constraints match: ~r/^[\p{L}\p{N}\w\s\-\.・（）「」]+$/u
    end

    attribute :contact_email, :string do
      allow_nil? true
    end

    attribute :contact_phone, :string do
      allow_nil? true
    end

    attribute :notes, :string do
      allow_nil? true
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    has_many :addresses, OpenSauce.CRM.Address do
      public? true
      domain OpenSauce.CRM
    end
  end
end
