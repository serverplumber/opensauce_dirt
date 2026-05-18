defmodule OpenSauce.Orders.Job do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_jobs"
    repo OpenSauce.Repo

    custom_indexes do
      index [:customer_id], name: "orders_jobs_customer_id_index"
      index [:scheduled_at], name: "orders_jobs_scheduled_at_index"
      index [:status], name: "orders_jobs_status_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [scheduled_at: :asc])
    end

    read :upcoming do
      filter expr(status == :scheduled and scheduled_at >= ^DateTime.utc_now())
      prepare build(sort: [scheduled_at: :asc])
    end

    create :create do
      primary? true
      accept [
        :service_type,
        :customer_id,
        :address_id,
        :scheduled_at,
        :estimated_duration_minutes,
        :status,
        :notes,
        :organisation_id
      ]
    end

    update :update do
      accept [
        :service_type,
        :address_id,
        :scheduled_at,
        :estimated_duration_minutes,
        :status,
        :invoiced,
        :notes
      ]
    end

    # Decoupled status transitions — safe to call from any context.
    # Arrival events drive mark_in_progress; departure does not auto-complete.
    update :mark_in_progress do
      accept []
      change set_attribute(:status, :in_progress)
    end

    update :complete do
      accept []
      change set_attribute(:status, :completed)
    end

    update :cancel do
      accept []
      change set_attribute(:status, :cancelled)
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

    attribute :service_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:installation, :maintenance, :delivery, :consultation, :pruning, :open_garden, :winterize_garden]
    end

    attribute :scheduled_at, :utc_datetime do
      allow_nil? true
      public? true
    end

    # Minutes. Nil means duration is unknown at scheduling time.
    attribute :estimated_duration_minutes, :integer do
      allow_nil? true
      public? true
      constraints min: 0
    end

    # Status flow:
    #   :scheduled   — job is planned, no one on site yet
    #   :in_progress — triggered automatically when an arrival event is logged
    #   :completed   — manually marked done; ready for invoicing
    #   :cancelled   — job did not happen
    # Transitions: :scheduled → :in_progress (on arrival) → :completed | :cancelled
    #              :scheduled → :cancelled (no-show)
    # Events (arrival/departure) are append-only and logged independently via JobEvent.
    # Departure does NOT auto-complete the job — must be marked complete explicitly.
    attribute :status, :atom do
      allow_nil? false
      public? true
      default :scheduled
      constraints one_of: [:scheduled, :in_progress, :completed, :cancelled]
    end

    attribute :invoiced, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 2000
    end

    timestamps()
  end

  aggregates do
    # Current odometer baseline: max km logged across all events for this job.
    # Used as the pre-fill default when logging any event. Generalises as the
    # business grows — no per-vehicle tracking yet.
    max :current_odometer_km, :events, :odometer_km
  end

  calculations do
    calculate :actual_duration_minutes,
              :integer,
              OpenSauce.Orders.Job.Calculations.ActualDurationMinutes
  end

  relationships do
    belongs_to :customer, OpenSauce.CRM.Customer do
      allow_nil? false
      public? true
      domain OpenSauce.CRM
    end

    # A customer's garden or indoor address — determines indoor vs outdoor job.
    belongs_to :address, OpenSauce.CRM.Address do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.CRM
    end

    has_many :events, OpenSauce.Orders.JobEvent do
      public? true
    end

    has_many :materials, OpenSauce.Orders.JobMaterial do
      public? true
    end
  end
end
