# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

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
      accept [:quantity, :cost, :price]
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

    # Zero is valid — a plant can be on the job at qty 0 to record a gifted/presented item.
    # Use destroy to remove the line; do not treat 0 as a removal signal.
    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    # What the org paid externally for this material on this job.
    # Distinct from SupplierCatalogItem.unit_price (catalogue list price), which is often
    # absent for plants. Filled in when the supplier invoice is known; nil until then.
    attribute :cost, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    # Billable rate or MSRP to the client for this material on this job.
    # Independent of cost and catalogue price — set when quoting or invoicing.
    attribute :price, :decimal do
      allow_nil? true
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
