defmodule OpenSauce.CRM.Plant do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "crm_plants"
    repo OpenSauce.Repo
  end

  actions do
    default_accept [:name, :form, :size, :cost, :note]
    defaults [:read, :destroy]

    create :create do
      primary? true
    end

    update :update do
      primary? true
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

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :form, :atom do
      allow_nil? true
      public? true
      constraints one_of: [:seed, :bulb, :division, :cutting, :specimen]
    end

    attribute :size, :string do
      allow_nil? true
      public? true
    end

    attribute :cost, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :note, :string do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :engagement_plants, OpenSauce.CRM.EngagementPlant
    has_many :job_plants, OpenSauce.Orders.JobPlant, domain: OpenSauce.Orders
    has_many :job_event_plants, OpenSauce.Orders.JobEventPlant, domain: OpenSauce.Orders
  end
end
