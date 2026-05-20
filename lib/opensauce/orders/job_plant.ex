defmodule OpenSauce.Orders.JobPlant do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_plants"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:job_id, :plant_id, :date, :organisation_id]
    end

    update :update do
      accept [:date]
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

    attribute :date, :date do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :job, OpenSauce.Orders.Job do
      allow_nil? false
      public? true
    end

    belongs_to :plant, OpenSauce.CRM.Plant do
      allow_nil? false
      public? true
      domain OpenSauce.CRM
    end
  end
end
