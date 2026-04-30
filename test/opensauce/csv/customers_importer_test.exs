defmodule OpenSauce.CSV.CustomersImporterTest do
  use OpenSauce.DataCase, async: true

  alias OpenSauce.CRM
  alias OpenSauce.CSV.Importers.Customers

  describe "dry_run/2" do
    test "flags invalid email" do
      csv = "type,first_name,last_name,email\nindividual,Jane,Doe,invalid\n"

      assert {:ok, %{rows: [], errors: errors}} =
               Customers.dry_run(csv, delimiter: ",", mapping: %{})

      assert Enum.any?(errors, &String.contains?(&1.message, "Invalid email"))
    end
  end

  describe "import/2" do
    test "inserts and updates customers by email" do
      actor = OpenSauce.DataCase.staff_actor()

      csv = "type,first_name,last_name,email\nindividual,Jane,Doe,jane@example.com\n"

      assert {:ok, %{inserted: 1, updated: 0, errors: []}} =
               Customers.import(csv, delimiter: ",", mapping: %{}, actor: actor)

      assert {:ok, _} = CRM.get_customer_by_email("jane@example.com", actor: actor)

      csv2 = "type,first_name,last_name,email\nindividual,Janet,Doe,jane@example.com\n"

      assert {:ok, %{inserted: 0, updated: updated, errors: []}} =
               Customers.import(csv2, delimiter: ",", mapping: %{}, actor: actor)

      assert updated >= 1
    end
  end
end
