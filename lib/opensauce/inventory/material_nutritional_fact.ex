defmodule OpenSauce.Inventory.MaterialNutritionalFact do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_material_nutritional_fact"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:nutritional_fact_id, :material_id, :amount, :unit]
    end
  end

  policies do
    # Public read (used for nutrition labels and planner exports)
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    attribute :amount, :decimal do
      public? true
      allow_nil? false
    end

    attribute :unit, :unit do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :material, OpenSauce.Inventory.Material, primary_key?: true, allow_nil?: false

    belongs_to :nutritional_fact, OpenSauce.Inventory.NutritionalFact,
      primary_key?: true,
      allow_nil?: false
  end
end
