defmodule OpenSauce.Orders.JobMaterial do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_materials"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:job_id, :material_id, :quantity, :organisation_id]
    end

    update :update do
      accept [:quantity]
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
      public? true
      constraints min: 0
    end

    timestamps()
  end

  relationships do
    belongs_to :job, OpenSauce.Orders.Job do
      allow_nil? false
      public? true
    end

    belongs_to :material, OpenSauce.Inventory.Material do
      allow_nil? false
      public? true
      domain OpenSauce.Inventory
    end
  end
end
