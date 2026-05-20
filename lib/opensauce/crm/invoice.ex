defmodule OpenSauce.CRM.Invoice do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "crm_invoices"
    repo OpenSauce.Repo

    custom_indexes do
      index [:customer_id], name: "crm_invoices_customer_id_index"
      index [:engagement_id], name: "crm_invoices_engagement_id_index"
      index [:status], name: "crm_invoices_status_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :reference,
        :customer_id,
        :engagement_id,
        :issued_on,
        :due_on,
        :amount,
        :status,
        :notes,
        :organisation_id
      ]
    end

    update :update do
      accept [
        :reference,
        :engagement_id,
        :issued_on,
        :due_on,
        :amount,
        :status,
        :notes
      ]
    end

    update :mark_paid do
      accept []
      change set_attribute(:status, :paid)
    end

    update :mark_sent do
      accept []
      change set_attribute(:status, :sent)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :issued_on, :date do
      allow_nil? false
      public? true
      default &Date.utc_today/0
    end

    attribute :due_on, :date do
      allow_nil? true
      public? true
    end

    attribute :amount, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :sent, :paid, :void]
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    belongs_to :customer, OpenSauce.CRM.Customer do
      allow_nil? false
      public? true
    end

    belongs_to :engagement, OpenSauce.CRM.Engagement do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    has_many :jobs, OpenSauce.Orders.Job do
      public? true
      domain OpenSauce.Orders
    end
  end
end
