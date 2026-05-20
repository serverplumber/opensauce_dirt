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

  alias OpenSauce.Orders.JobEvent.TagOnly
  alias OpenSauce.Orders.JobEvent.OdometerData

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
      accept [:job_id, :data, :timestamp, :note, :organisation_id]
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

    attribute :data, :union do
      allow_nil? false
      public? true

      constraints types: [
                    arrival:            [type: OdometerData, tag: :type, tag_value: :arrival],
                    departure:          [type: OdometerData, tag: :type, tag_value: :departure],
                    shift_start:        [type: OdometerData, tag: :type, tag_value: :shift_start],
                    shift_end:          [type: OdometerData, tag: :type, tag_value: :shift_end],
                    work_session_start: [type: TagOnly,   tag: :type, tag_value: :work_session_start],
                    work_session_stop:  [type: TagOnly,   tag: :type, tag_value: :work_session_stop]
                  ]
    end

    # User-recorded time of the event, not the insert time.
    attribute :timestamp, :utc_datetime do
      allow_nil? false
      public? true
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

    has_many :plant_links, OpenSauce.Orders.JobEventPlant do
      public? true
    end

    has_many :material_links, OpenSauce.Orders.JobEventMaterial do
      public? true
    end
  end
end
