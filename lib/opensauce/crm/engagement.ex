defmodule OpenSauce.CRM.Engagement do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  alias OpenSauce.CRM.Engagement.Signature

  postgres do
    table "crm_engagements"
    repo OpenSauce.Repo

    custom_indexes do
      index [:customer_id]
      index [:garden_id]
      index [:status]
    end
  end

  actions do
    default_accept [
      :garden_id,
      :customer_id,
      :scope_title,
      :scope_description,
      :install_price,
      :maintenance_price_annual,
      :term_start,
      :term_end,
      :status,
      :signature,
      :notes
    ]

    defaults [:read, :destroy]

    read :search do
      argument :query, :string, allow_nil?: false

      filter expr(
               fragment("? ILIKE '%' || ? || '%'", scope_title, ^arg(:query)) or
                 fragment("? ILIKE '%' || ? || '%'", customer.company_name_nickname, ^arg(:query)) or
                 fragment("? ILIKE '%' || ? || '%'", customer.first_name, ^arg(:query)) or
                 fragment("? ILIKE '%' || ? || '%'", customer.last_name, ^arg(:query)) or
                 fragment("? ILIKE '%' || ? || '%'", garden.name, ^arg(:query))
             )

      prepare build(limit: 50)
    end

    create :create do
      primary? true
    end

    update :update do
      primary? true
      require_atomic? false
    end

    update :sign do
      accept []
      require_atomic? false
      argument :signature, :map, allow_nil?: false

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :signed)
        |> Ash.Changeset.change_attribute(:signature, Ash.Changeset.get_argument(changeset, :signature))
      end
    end
  end

  policies do
    bypass expr(^actor(:role) == :owner) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :scope_title, :string do
      allow_nil? true
      public? true
    end

    attribute :scope_description, :string do
      allow_nil? true
      public? true
    end

    attribute :install_price, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :maintenance_price_annual, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :term_start, :date do
      allow_nil? true
      public? true
    end

    attribute :term_end, :date do
      allow_nil? true
      public? true
    end

    # Status flow:
    #   :draft       — being authored, not yet sent to client
    #   :proposed    — sent to client for review
    #   :signed      — client signed; signature embedded below
    #   :in_progress — active work underway
    #   :completed   — all work done, ready for final invoice
    #   :cancelled   — did not proceed
    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :proposed, :signed, :in_progress, :completed, :cancelled]
    end

    # Set by the :sign action. Nil until the client signs.
    attribute :signature, Signature do
      allow_nil? true
      public? true
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :garden, OpenSauce.CRM.Address do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    # Denormalized for query convenience — also derivable via garden.customer_id.
    belongs_to :customer, OpenSauce.CRM.Customer do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    # All images (photos and paintings) attached to this engagement, newest first.
    # Use the :paintings_for_engagement action (or filter images by type == :painting)
    # to determine invoice description style: "Garden as drawn" vs "Garden as described".
    has_many :images, OpenSauce.CRM.EngagementImage do
      public? true
    end

    has_many :materials, OpenSauce.CRM.EngagementMaterial do
      public? true
    end

    has_many :jobs, OpenSauce.Orders.Job do
      public? true
      domain OpenSauce.Orders
    end
  end

  calculations do
    # First-year quoted value: install (one-off) + one year of maintenance.
    calculate :total_quoted_value, :decimal, fn records, _ ->
      {:ok,
       Enum.map(records, fn e ->
         install = e.install_price || Decimal.new(0)
         maintenance = e.maintenance_price_annual || Decimal.new(0)
         Decimal.add(install, maintenance)
       end)}
    end

    # Stubs — require Invoice and consumption resources not yet defined.
    calculate :total_invoiced, :decimal, fn records, _ ->
      {:ok, Enum.map(records, fn _ -> nil end)}
    end

    calculate :total_realized_cost, :decimal, fn records, _ ->
      {:ok, Enum.map(records, fn _ -> nil end)}
    end

    calculate :realized_margin, :decimal, fn records, _ ->
      {:ok, Enum.map(records, fn _ -> nil end)}
    end

    calculate :realized_margin_percent, :decimal, fn records, _ ->
      {:ok, Enum.map(records, fn _ -> nil end)}
    end
  end
end
