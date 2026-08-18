# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.PurchaseOrder do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]

  alias OpenSauce.Inventory.PurchaseOrder.Types.Status

  json_api do
    type "purchase-order"

    routes do
      base("/purchase-orders")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :purchase_order

    queries do
      get(:get_purchase_order, :read)
      list(:list_purchase_orders, :list)
    end

    mutations do
      create :create_purchase_order, :create
      update :update_purchase_order, :update
    end
  end

  postgres do
    table "inventory_purchase_orders"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [inserted_at: :desc], load: [:supplier])
    end

    read :list_draft do
      filter expr(status == :draft)
      prepare build(sort: [inserted_at: :desc])
    end

    create :create do
      primary? true
      accept [:supplier_id, :status, :ordered_at]
      change set_attribute(:status, :draft)
      change OpenSauce.Inventory.Changes.AssignPurchaseOrderReference
    end

    update :update do
      accept [:supplier_id, :status, :ordered_at, :received_at]
    end

    update :mark_ordered do
      accept []
      change set_attribute(:status, :ordered)
      change set_attribute(:ordered_at, &DateTime.utc_now/0)
    end

    update :confirm do
      accept []
      change set_attribute(:status, :confirmed)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      writable? false
      allow_nil? false
      generated? true
    end

    attribute :status, Status do
      allow_nil? false
      default :draft
    end

    attribute :ordered_at, :utc_datetime do
      allow_nil? true
    end

    attribute :received_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :supplier, OpenSauce.Inventory.Supplier do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    has_many :items, OpenSauce.Inventory.PurchaseOrderItem
  end

  identities do
    identity :reference, [:reference]
  end
end
