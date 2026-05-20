defmodule OpenSauce.Orders.JobEventPlant do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_event_plants"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :log do
      primary? true
      accept [:job_event_id, :plant_id, :role, :date, :organisation_id]
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

    attribute :role, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:install, :propagate, :harvest, :pickup, :dropoff, :reception]
    end

    attribute :date, :date do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :job_event, OpenSauce.Orders.JobEvent do
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
