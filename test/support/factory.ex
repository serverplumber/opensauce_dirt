# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Test.Factory do
  @moduledoc false

  alias OpenSauce.CRM.{Customer, Engagement}
  alias OpenSauce.Inventory.{Material, Supplier, SupplierCatalog, SupplierCatalogItem}
  alias OpenSauce.Work.Job

  @doc """
  Creates a Material. Accepts optional attribute overrides and an optional actor
  (OrganisationMember). When no actor is provided, a fresh staff member is created.
  """
  def create_material!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()

    defaults = %{
      name: "Material #{System.unique_integer([:positive])}",
      sku: "MAT-#{System.unique_integer([:positive])}",
      unit: :gram,
      price: Decimal.new("1.00"),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    }

    Material
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates a Customer. Accepts optional attribute overrides and an optional actor.
  Includes a default garden address (required by the create action).
  Returns the customer with :garden_addresses loaded so callers can extract garden IDs.
  """
  def create_customer!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()

    defaults = %{
      type: :individual,
      first_name: "Test",
      last_name: "Customer#{System.unique_integer([:positive])}",
      email: "test+#{System.unique_integer([:positive])}@local",
      garden_addresses: [%{is_garden: true, is_billing: false, is_indoor: false, city: "Springfield", country: "US"}]
    }

    customer =
      Customer
      |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
      |> Ash.create!(actor: member, tenant: member.organisation_id)

    Ash.load!(customer, :garden_addresses, actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates an Engagement. Accepts optional attribute overrides and an optional actor.
  Engagement create requires manager+ role, so defaults to admin_actor when none is provided.
  Auto-creates a Customer (with garden) when :customer_id is not in attrs, and sets
  :garden_id from that customer's first garden.
  """
  def create_engagement!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.admin_actor()

    {customer_id, garden_id} =
      if Map.has_key?(attrs, :customer_id) do
        {attrs[:customer_id], Map.get(attrs, :garden_id)}
      else
        customer = create_customer!(%{}, member)
        first_garden = List.first(customer.garden_addresses)
        {customer.id, first_garden && first_garden.id}
      end

    n = System.unique_integer([:positive])

    defaults = %{
      customer_id: customer_id,
      garden_id: garden_id,
      scope_title: "Test Engagement #{n}",
      status: :draft
    }

    Engagement
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates a Job. Accepts optional attribute overrides and an optional actor.
  Defaults to type: :client_work with service_category: :installation.
  Auto-creates a Customer and uses their first garden for :garden_id when type is
  :client_work and :garden_id is not supplied (installation requires a garden).
  For :shift and :internal_work, no garden is created.
  """
  def create_job!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()
    type = Map.get(attrs, :type, :client_work)

    defaults =
      case type do
        :client_work ->
          garden_id =
            if Map.has_key?(attrs, :garden_id) do
              Map.get(attrs, :garden_id)
            else
              customer = create_customer!(%{}, member)
              customer.garden_addresses |> List.first() |> Map.get(:id)
            end

          %{type: :client_work, service_category: :installation, garden_id: garden_id, status: :scheduling}

        :shift ->
          %{type: :shift, status: :scheduling}

        :internal_work ->
          %{type: :internal_work, account_code: :production, status: :scheduling}
      end

    params = defaults |> Map.merge(attrs) |> Map.put(:organisation_id, member.organisation_id)

    Job
    |> Ash.Changeset.for_create(:create, params, tenant: member.organisation_id)
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates a Venue. Accepts optional attribute overrides and an optional actor.
  """
  def create_venue!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()

    n = System.unique_integer([:positive])

    defaults = %{
      name: "Venue #{n}",
      organisation_id: member.organisation_id
    }

    OpenSauce.Operations.Venue
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates a Supplier. Accepts optional attribute overrides and an optional actor.
  """
  def create_supplier!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()

    defaults = %{
      name: "Supplier #{System.unique_integer([:positive])}"
    }

    Supplier
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates a SupplierCatalog. Auto-creates a Supplier when :supplier_id is not in attrs.
  """
  def create_catalog!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()

    supplier_id =
      if Map.has_key?(attrs, :supplier_id) do
        attrs[:supplier_id]
      else
        create_supplier!(%{}, member).id
      end

    n = System.unique_integer([:positive])

    defaults = %{
      name: "Catalog #{n}",
      supplier_id: supplier_id,
      season: :year_round,
      year: Date.utc_today().year
    }

    SupplierCatalog
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end

  @doc """
  Creates a SupplierCatalogItem. Auto-creates a SupplierCatalog (and its Supplier) when
  :supplier_catalog_id is not in attrs. :material_id is optional.
  """
  def create_catalog_item!(attrs \\ %{}, actor \\ nil) do
    member = actor || OpenSauce.DataCase.staff_actor()

    catalog_id =
      if Map.has_key?(attrs, :supplier_catalog_id) do
        attrs[:supplier_catalog_id]
      else
        create_catalog!(%{}, member).id
      end

    n = System.unique_integer([:positive])

    defaults = %{
      supplier_catalog_id: catalog_id,
      sku: "SCI-#{n}",
      name: "Item #{n}",
      category: :plant
    }

    SupplierCatalogItem
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: member, tenant: member.organisation_id)
  end
end
