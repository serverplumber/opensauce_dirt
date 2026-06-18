# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Test.Factory do
  @moduledoc false

  alias OpenSauce.CRM.Customer
  alias OpenSauce.Inventory.{Material, Supplier}

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

    Customer
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
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
end
