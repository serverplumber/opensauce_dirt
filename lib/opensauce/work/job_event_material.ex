defmodule OpenSauce.Work.JobEventMaterial do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Work,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_event_materials"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :for_event do
      argument :job_event_id, :uuid, allow_nil?: false
      filter expr(job_event_id == ^arg(:job_event_id))
    end

    create :log do
      primary? true
      accept [:job_event_id, :material_id, :quantity, :organisation_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :destroy]) do
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
    belongs_to :job_event, OpenSauce.Work.JobEvent do
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
