defmodule OpenSauce.Orders.Job do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted],
    primary_read_warning?: false

  postgres do
    table "orders_jobs"
    repo OpenSauce.Repo

    custom_indexes do
      index [:scheduled_for], name: "orders_jobs_scheduled_for_index"
      index [:status], name: "orders_jobs_status_index"
      index [:containing_shift_id], name: "orders_jobs_containing_shift_id_index"
      index [:engagement_id], name: "orders_jobs_engagement_id_index"
      index [:garden_id], name: "orders_jobs_garden_id_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      primary? true
      prepare build(sort: [scheduled_for: :asc])
    end

    read :upcoming do
      filter expr(status == :scheduled and not is_nil(scheduled_for) and scheduled_for >= ^Date.utc_today())
      prepare build(sort: [scheduled_for: :asc])
    end

    read :for_shift do
      argument :shift_id, :uuid, allow_nil?: false
      filter expr(containing_shift_id == ^arg(:shift_id))
      prepare build(sort: [scheduled_for: :asc])
    end

    read :active_shift do
      filter expr(type == :shift and status == :in_progress)
    end

    read :at_garden do
      argument :garden_id, :uuid, allow_nil?: false
      filter expr(garden_id == ^arg(:garden_id) and status in [:scheduling, :scheduled, :in_progress])
      prepare build(sort: [scheduled_for: :asc])
    end

    create :create do
      primary? true
      accept [
        :type,
        :service_category,
        :account_code,
        :garden_id,
        :engagement_id,
        :containing_shift_id,
        :actor_id,
        :scheduled_for,
        :due_by,
        :duration_estimate,
        :status,
        :notes,
        :organisation_id
      ]
    end

    update :update do
      require_atomic? false
      accept [
        :type,
        :service_category,
        :account_code,
        :garden_id,
        :engagement_id,
        :containing_shift_id,
        :actor_id,
        :scheduled_for,
        :start_time,
        :due_by,
        :duration_estimate,
        :status,
        :notes
      ]
    end

    update :mark_in_progress do
      require_atomic? false
      accept []
      change set_attribute(:status, :in_progress)
    end

    update :complete do
      require_atomic? false
      accept []
      change set_attribute(:status, :completed)
      change OpenSauce.Orders.Job.Changes.SnapshotRealizedCost
    end

    update :write_realized_cost do
      require_atomic? false
      accept [:realized_cost]
    end

    update :cancel do
      require_atomic? false
      accept []
      change set_attribute(:status, :cancelled)
    end
  end

  validations do
    validate present(:service_category),
      where: [attribute_equals(:type, :client_work)],
      message: "is required for client work"

    validate present(:account_code),
      where: [attribute_equals(:type, :internal_work)],
      message: "is required for internal work"

    validate absent(:garden_id),
      where: [attribute_equals(:type, :shift)],
      message: "shift jobs cannot have a garden"

    validate absent(:engagement_id),
      where: [attribute_equals(:type, :shift)],
      message: "shift jobs cannot have an engagement"

    validate {OpenSauce.Orders.Job.Validations.RequireGardenForAddressable, []}
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

    attribute :type, :atom do
      allow_nil? false
      public? true
      default :client_work
      constraints one_of: [:client_work, :shift, :internal_work]
    end

    attribute :service_category, :atom do
      allow_nil? true
      public? true
      constraints one_of: [:installation, :delivery, :pruning, :consultation, :design, :opening, :winterization, :maintenance]
    end

    attribute :account_code, :atom do
      allow_nil? true
      public? true
      constraints one_of: [:production, :maintenance]
    end

    attribute :scheduled_for, :date do
      allow_nil? true
      public? true
    end

    attribute :start_time, :time do
      allow_nil? true
      public? true
    end

    # scheduling  — identified but not yet placed on the calendar; use due_by for the deadline
    # scheduled   — on the calendar with a confirmed scheduled_for date
    # in_progress — triggered when an arrival event is logged
    # completed   — manually marked done; ready for invoicing
    # cancelled   — job did not happen
    attribute :status, :atom do
      allow_nil? false
      public? true
      default :scheduling
      constraints one_of: [:scheduling, :scheduled, :in_progress, :completed, :cancelled]
    end

    attribute :due_by, :date do
      allow_nil? true
      public? true
    end

    attribute :duration_estimate, :integer do
      allow_nil? true
      public? true
      constraints min: 1
    end

    attribute :realized_cost, :decimal do
      allow_nil? true
      public? true
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 2000
    end

    timestamps()
  end

  calculations do
    # Pair-walks arrival/departure (or shift_start/shift_end) events to sum elapsed time.
    calculate :duration, :integer, OpenSauce.Orders.Job.Calculations.Duration

    # Odometer diff: shift_start → shift_end for :shift, arrival → departure for others.
    calculate :mileage_km, :decimal, OpenSauce.Orders.Job.Calculations.MileageKm

    calculate :materials_cost, :decimal, OpenSauce.Orders.Job.Calculations.MaterialsCost

    # Sum of tentative staff hourly rates — used for calendar scheduling and cost estimation.
    calculate :man_hour_rate, :decimal, OpenSauce.Orders.Job.Calculations.ManHourRate

    # duration_estimate (minutes) expressed as hours.
    calculate :estimated_man_hours, :decimal, OpenSauce.Orders.Job.Calculations.EstimatedManHours

    # Rough estimate: estimated_man_hours × man_hour_rate × overhead + materials.
    calculate :estimated_cost, :decimal, OpenSauce.Orders.Job.Calculations.EstimatedCost
  end

  relationships do
    # The garden (outdoor site) this job is at. All :client_work jobs require one.
    belongs_to :garden, OpenSauce.CRM.Address do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.CRM
    end

    belongs_to :engagement, OpenSauce.CRM.Engagement do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.CRM
    end

    belongs_to :invoice, OpenSauce.CRM.Invoice do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.CRM
    end

    # :client_work and :internal_work jobs reference the :shift job that contains them.
    belongs_to :containing_shift, OpenSauce.Orders.Job do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    # Child jobs belonging to this shift (meaningful when type == :shift).
    has_many :jobs, OpenSauce.Orders.Job do
      public? true
      destination_attribute :containing_shift_id
    end

    # Who is doing the work on this job.
    belongs_to :actor, OpenSauce.Accounts.User do
      allow_nil? true
      public? true
      attribute_writable? true
      domain OpenSauce.Accounts
    end

    # Tentative staff assigned to this job — drives calendar visibility and cost estimation.
    has_many :staff_assignments, OpenSauce.Orders.JobStaff do
      public? true
    end

    has_many :events, OpenSauce.Orders.JobEvent do
      public? true
    end

    has_many :materials, OpenSauce.Orders.JobMaterial do
      public? true
    end
  end
end
