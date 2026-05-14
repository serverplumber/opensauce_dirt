defmodule OpenSauce.Orders.JobEvent do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_events"
    repo OpenSauce.Repo

    custom_indexes do
      index [:job_id, :timestamp], name: "orders_job_events_job_timeline_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    # Events are append-only: log and forget. No update action.
    read :for_job do
      argument :job_id, :uuid, allow_nil?: false
      filter expr(job_id == ^arg(:job_id))
      prepare build(sort: [timestamp: :asc])
    end

    create :log do
      primary? true
      accept [:job_id, :type, :timestamp, :odometer_km, :note, :organisation_id]
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

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:arrival, :departure]
    end

    # User-recorded time of the event, not the insert time.
    attribute :timestamp, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :odometer_km, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :note, :string do
      allow_nil? true
      public? true
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    belongs_to :job, OpenSauce.Orders.Job do
      allow_nil? false
      public? true
    end
  end
end
