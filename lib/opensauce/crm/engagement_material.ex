defmodule OpenSauce.CRM.EngagementMaterial do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "crm_engagement_materials"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:engagement_id, :supplier_catalog_item_id, :quantity, :note, :scheduled_date, :organisation_id]
    end

    update :update do
      primary? true
      accept [:quantity, :scheduled_date, :note]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :scheduled_date, :date do
      allow_nil? true
      public? true
    end

    attribute :note, :string do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :engagement, OpenSauce.CRM.Engagement do
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
