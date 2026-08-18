# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.Movement do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]

  json_api do
    type "movement"

    routes do
      base("/movements")
      get(:read)
      index :read
    end
  end

  graphql do
    type :movement

    queries do
      get(:get_movement, :read)
      list(:list_movements, :read)
    end
  end

  postgres do
    table "inventory_movements"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :adjust_stock do
      accept [:material_id, :quantity, :reason]
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
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

    attribute :quantity, :decimal do
      allow_nil? false
    end

    attribute :reason, :string do
      allow_nil? true
      constraints max_length: 255
    end

    attribute :occurred_at, :utc_datetime do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :material, OpenSauce.Inventory.Material do
      allow_nil? false
    end
  end
end
