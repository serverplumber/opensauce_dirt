# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.SupplierNameValidationTest do
  use OpenSauce.DataCase, async: true

  alias OpenSauce.Inventory.Supplier

  defp staff, do: OpenSauce.DataCase.staff_actor()

  defp create_supplier(name, contact_name \\ nil) do
    member = staff()
    params = %{name: name}
    params = if contact_name, do: Map.put(params, :contact_name, contact_name), else: params

    Supplier
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create(actor: member, tenant: member.organisation_id)
  end

  describe "supplier name validation" do
    test "accepts ASCII name" do
      assert {:ok, _} = create_supplier("ACME Supplies")
    end

    test "accepts Japanese name" do
      assert {:ok, _} = create_supplier("東京食材株式会社")
    end

    test "rejects invalid chars" do
      assert {:error, changeset} = create_supplier("ACME@Supplies")
      assert inspect(changeset.errors) =~ "must match"
    end
  end

  describe "supplier contact_name validation" do
    test "accepts Japanese contact name" do
      assert {:ok, _} = create_supplier("Supplier A", "田中太郎")
    end

    test "rejects invalid chars in contact name" do
      assert {:error, changeset} = create_supplier("Supplier B", "John#Doe")
      assert inspect(changeset.errors) =~ "must match"
    end
  end
end
