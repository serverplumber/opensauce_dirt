defmodule OpenSauce.Accounts.Organisation do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "accounts_organisations"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:name, :slug]]

    @new_fields [
      :legal_name,
      :website,
      :phone,
      :payment_info,
      :invoice_terms,
      :invoice_footer,
      :invoice_annual_nominal_rate,
      :contact_name,
      :contact_title,
      :contact_phone,
      :contact_email,
      :estimate_sign_off_items
    ]

    update :update do
      accept [
               :name,
               :currency,
               :tax_mode,
               :labor_overhead_percent,
               :mileage_cost_per_km,
               :email_from_name,
               :email_from_address,
               :head_office_venue_id
             ] ++ @new_fields
    end

    update :update_settings do
      accept [
               :name,
               :currency,
               :tax_mode,
               :labor_overhead_percent,
               :mileage_cost_per_km,
               :email_from_name,
               :email_from_address,
               :next_invoice_number,
               :invoice_annual_nominal_rate
             ] ++ @new_fields
    end

    update :update_logos do
      accept [:logo_colour_key, :logo_greyscale_key]
    end

    update :update_brand_theme do
      accept [:brand_theme]
      require_atomic? false

      change fn changeset, _context ->
        case Ash.Changeset.fetch_change(changeset, :brand_theme) do
          {:ok, nil} ->
            changeset

          {:ok, theme} ->
            case OpenSauce.BrandTheme.sanitize(theme) do
              {:ok, clean} ->
                Ash.Changeset.force_change_attribute(changeset, :brand_theme, clean)

              :error ->
                Ash.Changeset.add_error(changeset,
                  field: :brand_theme,
                  message: "is not a valid brand theme"
                )
            end

          :error ->
            changeset
        end
      end
    end
  end

  policies do
    # TODO: tighten once session/auth flow is finalised
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :currency, OpenSauce.Types.Currency do
      public? true
      allow_nil? false
      default :CAD
    end

    attribute :tax_mode, :atom do
      public? true
      allow_nil? false
      default :exclusive
      constraints one_of: [:inclusive, :exclusive]
    end

    attribute :labor_overhead_percent, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :mileage_cost_per_km, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :email_from_name, :string do
      public? true
      default "OpenSauce"
    end

    attribute :email_from_address, :string do
      public? true
    end

    attribute :legal_name, :string do
      public? true
      allow_nil? true
    end

    attribute :website, :string do
      public? true
      allow_nil? true
    end

    attribute :phone, :string do
      public? true
      allow_nil? true
    end

    attribute :payment_info, :string do
      public? true
      allow_nil? true
    end

    attribute :invoice_terms, :string do
      public? true
      allow_nil? true

      default "Tout solde impayé porte intérêt à compter du 31e jour suivant la date de facturation, au taux annuel de 24 %, composé quotidiennement."
    end

    attribute :invoice_annual_nominal_rate, :decimal do
      public? true
      allow_nil? true
      constraints min: 0, max: 35
    end

    attribute :invoice_footer, :string do
      public? true
      allow_nil? true
    end

    # Items the client must acknowledge before signing an estimate.
    # Each item: %{"label" => string, "body" => string | nil}
    # label = the checkbox text; body = optional terms text shown above it.
    attribute :estimate_sign_off_items, {:array, :map} do
      public? true
      allow_nil? false
      default []
    end

    attribute :contact_name, :string do
      public? true
      allow_nil? true
    end

    attribute :contact_title, :string do
      public? true
      allow_nil? true
    end

    attribute :contact_phone, :string do
      public? true
      allow_nil? true
    end

    attribute :contact_email, :string do
      public? true
      allow_nil? true
    end

    attribute :next_invoice_number, :integer do
      public? true
      allow_nil? false
      default 1
      constraints min: 1
    end

    attribute :next_po_number, :integer do
      public? true
      allow_nil? false
      default 1
      constraints min: 1
    end

    attribute :logo_colour_key, :string do
      public? true
      allow_nil? true
    end

    attribute :logo_greyscale_key, :string do
      public? true
      allow_nil? true
    end

    # Palette extracted from the colour logo — see OpenSauce.BrandTheme.
    attribute :brand_theme, :map do
      public? true
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    has_one :address, OpenSauce.CRM.Address do
      public? true
      domain OpenSauce.CRM
      destination_attribute :organisation_id
    end

    belongs_to :head_office_venue, OpenSauce.Operations.Venue do
      public? true
      domain OpenSauce.Operations
      allow_nil? true
    end

    has_many :members, OpenSauce.Accounts.OrganisationMember
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
