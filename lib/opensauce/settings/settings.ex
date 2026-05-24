defmodule OpenSauce.Settings.Settings do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Settings,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]


  json_api do
    type "settings"

    routes do
      base("/settings")
      get(:get)
      patch(:update)
    end
  end

  postgres do
    table "settings"
    repo OpenSauce.Repo
  end

  actions do
    default_accept :*

    defaults [:read, :update]

    create :init do
      accept []
    end

    read :get do
      get? true
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {OpenSauce.Accounts.Checks.ApiScopeCheck, []}
    end

    # Allow read of settings for everyone (used across site)
    policy action_type(:read) do
      authorize_if always()
    end

    # Allow init (bootstrap) without auth
    policy action(:init) do
      authorize_if always()
    end

    # Restrict updates/deletes to admin
    policy action_type([:update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    # TODO(polish): workshop labor is a period cost, not tracked per plant. Hours
    # are spent tending all stock at a venue collectively, not per batch or per
    # plant. Proper model: use Shift hours per venue, amortize total shift cost
    # (hours × rate) across all lots at that venue in the period — same pattern
    # as electricity. Current BOM labor steps assume discrete per-batch attribution
    # which doesn't match this workflow.
    attribute :labor_hourly_rate, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
      description "Default hourly labor rate used for cost calculations."
    end

    # TODO(polish): electricity is a period cost, not a variable input — workshop
    # lights run continuously regardless of active labor, so it doesn't scale with
    # hours. Proper model: add `electricity_monthly` here and at batch cost-snapshot
    # time amortize it (month's electricity ÷ total batches that month). For now it
    # is folded into labor_overhead_percent as an approximation.
    attribute :labor_overhead_percent, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
      description "Applied as a percentage (0.0-1.0) of material + labor costs."
    end

    attribute :retail_markup_mode, :atom do
      public? true
      allow_nil? false
      default :percent
      constraints one_of: [:percent, :fixed]
    end

    attribute :retail_markup_value, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :wholesale_markup_mode, :atom do
      public? true
      allow_nil? false
      default :percent
      constraints one_of: [:percent, :fixed]
    end

    attribute :wholesale_markup_value, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

  end
end
