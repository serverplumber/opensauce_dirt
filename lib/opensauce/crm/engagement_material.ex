# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

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
      accept [:quantity, :scheduled_date, :note, :cost, :price]
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

    # Planned quantity for the engagement scope. May differ from what is ultimately
    # recorded on JobMaterials when the work is executed.
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

    # Estimated cost to the org for this material at engagement time (supplier price).
    # Used to cost the engagement and verify margin before signing. May be updated
    # as supplier quotes come in; the actual paid cost is recorded on JobMaterial.cost
    # once the job runs.
    attribute :cost, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    # Planned billable price to the client for this material.
    # Set when building the engagement quote to verify margin. May differ from the
    # final JobMaterial.price if pricing changes between quoting and execution.
    attribute :price, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
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
