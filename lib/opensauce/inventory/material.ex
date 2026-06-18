# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.Material do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]

  json_api do
    type "material"

    routes do
      base("/materials")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :material

    queries do
      get(:get_material, :read)
      list(:list_materials, :list)
    end

    mutations do
      create :create_material, :create
      update :update_material, :update
    end
  end

  postgres do
    table "inventory_materials"
    repo OpenSauce.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :name,
        :sku,
        :unit,
        :material_type,
        :price,
        :minimum_stock,
        :maximum_stock
      ]
    ]

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :sku,
        :unit,
        :material_type,
        :price,
        :minimum_stock,
        :maximum_stock
      ]

    end

    read :list do
      prepare build(sort: :name)

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: :name)
      pagination keyset?: true
    end
  end

  policies do
    # Public reads (used for planner math, printouts, and exports); restrict writes
    # API key scope check
    policy always() do
      authorize_if {OpenSauce.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false

      constraints min_length: 2,
                  max_length: 255,
                  match: ~r/^[\p{L}\p{N}\w\s\-\.・（）「」]+$/u
    end

    attribute :sku, :string do
      public? true
      allow_nil? false

      constraints min_length: 2,
                  max_length: 50
    end

    attribute :unit, :unit do
      public? true
      allow_nil? false
    end

    attribute :price, :decimal do
      public? true
      allow_nil? false
    end

    attribute :material_type, :atom do
      public? true
      allow_nil? false
      default :supply
      constraints one_of: [:supply, :plant]
    end

    attribute :minimum_stock, :decimal do
      public? true
      constraints min: 0
    end

    attribute :maximum_stock, :decimal do
      public? true
      constraints min: 0
    end

    timestamps()
  end

  relationships do
    has_many :movements, OpenSauce.Inventory.Movement
  end

  aggregates do
    sum :current_stock, :movements, :quantity
  end

  identities do
    identity :name, [:name]
    identity :sku, [:sku]
  end
end
