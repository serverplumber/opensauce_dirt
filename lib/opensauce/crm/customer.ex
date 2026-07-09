# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.CRM.Customer do
  # TODO_polish: destroy action should be owner-only. Non-owners should only be able
  # to hide a customer via an `active` flag, keeping the record intact for order history.
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]

  alias OpenSauce.CRM.Address

  require Ash.Resource.Preparation.Builtins

  json_api do
    type "customer"

    routes do
      base("/customers")
      get(:read)
      index :list
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  graphql do
    type :customer

    queries do
      get(:get_customer, :read)
      list(:list_customers, :list)
    end

    mutations do
      create :create_customer, :create
      update :update_customer, :update
      destroy :destroy_customer, :destroy
    end
  end

  postgres do
    table "crm_customers"
    repo OpenSauce.Repo
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    create :create do
      argument :garden_addresses, {:array, :map}, allow_nil?: true, default: []

      change fn changeset, _ ->
        gardens = Ash.Changeset.get_argument(changeset, :garden_addresses) || []

        if Enum.empty?(gardens) or Enum.any?(gardens, &billing_flagged?/1) do
          changeset
        else
          [first | rest] = gardens
          normalized = [Map.put(first, "is_billing", true) | rest]
          Ash.Changeset.set_argument(changeset, :garden_addresses, normalized)
        end
      end

      change manage_relationship(:garden_addresses,
               on_lookup: :relate,
               on_no_match: :create,
               on_match: :update,
               on_missing: :destroy
             )

      validate fn changeset, _ ->
        gardens = Ash.Changeset.get_argument(changeset, :garden_addresses) || []
        billing_count = Enum.count(gardens, &billing_flagged?/1)

        cond do
          gardens == [] ->
            {:error, field: :garden_addresses, message: "at least one garden address is required"}

          billing_count > 1 ->
            {:error, field: :garden_addresses, message: "only one garden can be the billing address"}

          Ash.Changeset.get_attribute(changeset, :type) == :company and
              is_nil(Ash.Changeset.get_attribute(changeset, :company_name_nickname)) ->
            {:error, field: :company_name_nickname, message: "is required for companies"}

          true ->
            :ok
        end
      end
    end

    update :update do
      require_atomic? false

      argument :garden_addresses, {:array, :map}, allow_nil?: true

      change fn changeset, _ ->
        case Ash.Changeset.get_argument(changeset, :garden_addresses) do
          nil ->
            changeset

          [] ->
            changeset

          gardens ->
            if Enum.any?(gardens, &billing_flagged?/1) do
              changeset
            else
              [first | rest] = gardens
              normalized = [Map.put(first, "is_billing", true) | rest]
              Ash.Changeset.set_argument(changeset, :garden_addresses, normalized)
            end
        end
      end

      change manage_relationship(:garden_addresses,
               on_lookup: :relate,
               on_no_match: :create,
               on_match: :update,
               on_missing: :destroy
             )

      validate fn changeset, _ ->
        type =
          Ash.Changeset.get_attribute(changeset, :type) ||
            Map.get(changeset.data, :type)

        company_name_nickname =
          Ash.Changeset.get_attribute(changeset, :company_name_nickname) ||
            Map.get(changeset.data, :company_name_nickname)

        gardens = Ash.Changeset.get_argument(changeset, :garden_addresses)

        billing_count =
          if is_list(gardens), do: Enum.count(gardens, &billing_flagged?/1)

        cond do
          gardens == [] ->
            {:error, field: :garden_addresses, message: "at least one garden address is required"}

          billing_count != nil and billing_count > 1 ->
            {:error, field: :garden_addresses, message: "only one garden can be the billing address"}

          type == :company and is_nil(company_name_nickname) ->
            {:error, field: :company_name_nickname, message: "is required for companies"}

          true ->
            :ok
        end
      end
    end

    # Narrow read used by checkout
    read :get_by_email do
      get? true
      argument :email, :string, allow_nil?: false
      filter expr(email == ^arg(:email))
    end

    read :list do
      prepare build(sort: :first_name)

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: :first_name)
      pagination keyset?: true
    end

    read :with_uninvoiced_jobs do
      prepare build(sort: :first_name)

      filter expr(exists(engagements, exists(jobs, is_nil(invoice_id) or invoice.status == :void)))
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {OpenSauce.Accounts.Checks.ApiScopeCheck, []}
    end

    # Admin can do anything
    bypass expr(^actor(:role) == :owner) do
      authorize_if always()
    end

    # Allow only targeted email lookup publicly
    policy action(:get_by_email) do
      authorize_if always()
    end

    # Allow public create/update (checkout address upsert). Consider narrowing in future.
    policy action_type([:create, :update]) do
      authorize_if always()
    end

    # Other reads/destroys restricted to staff/admin
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type(:destroy) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      writable? false

      default fn ->
        hex =
          (:rand.uniform(0x1000) - 1)
          |> Integer.to_string(16)
          |> String.downcase()
          |> String.pad_leading(3, "0")

        "cst_#{hex}"
      end

      allow_nil? false
      generated? true

      constraints match: ~r/^cst_[0-9a-f]{3}$/,
                  allow_empty?: false
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:individual, :company]
    end

    attribute :company_name_nickname, :string do
      allow_nil? true
      public? true
      constraints min_length: 1
    end

    attribute :first_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}\w\s\-\.・（）「」]+$/u
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}\w\s\-\.・（）「」]+$/u
    end

    attribute :email, :string do
      allow_nil? true
      public? true
      constraints match: ~r/@/
    end

    attribute :phone, :string do
      allow_nil? true
      public? true
      constraints max_length: 15
    end

    timestamps()
  end

  relationships do
    has_many :addresses, Address do
      public? true
    end

    has_one :billing_address, Address do
      filter expr(is_billing == true)
      public? true
    end

    has_many :garden_addresses, Address do
      filter expr(is_garden == true)
      public? true
    end

    has_many :indoor_addresses, Address do
      filter expr(is_indoor == true)
      public? true
    end

    has_many :invoices, OpenSauce.CRM.Invoice do
      public? true
    end

    has_many :engagements, OpenSauce.CRM.Engagement do
      public? true
    end
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name)

    calculate :has_uninvoiced_jobs,
              :boolean,
              expr(exists(engagements, exists(jobs, is_nil(invoice_id) or invoice.status == :void)))
  end

  aggregates do
  end

  identities do
    identity :phone, [:phone]
    identity :email, [:email]
    identity :reference, [:reference]
  end

  defp billing_flagged?(garden) when is_map(garden) do
    Map.get(garden, :is_billing) == true or Map.get(garden, "is_billing") in [true, "true"]
  end
end
