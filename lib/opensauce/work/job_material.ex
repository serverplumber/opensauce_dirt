defmodule OpenSauce.Work.JobMaterial do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Work,
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
      accept [:job_id, :supplier_catalog_item_id, :quantity, :organisation_id]
    end

    update :update do
      accept [:quantity]
    end

    update :move do
      accept [:job_id]
      require_atomic? false
      change OpenSauce.Work.JobMaterial.Changes.MovePoItem
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
    belongs_to :job, OpenSauce.Work.Job do
      allow_nil? false
      public? true
    end

    belongs_to :supplier_catalog_item, OpenSauce.Inventory.SupplierCatalogItem do
      allow_nil? false
      public? true
      domain OpenSauce.Inventory
    end
  end
end
