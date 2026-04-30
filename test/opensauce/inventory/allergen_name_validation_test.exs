defmodule OpenSauce.Inventory.AllergenNameValidationTest do
  use OpenSauce.DataCase, async: true

  alias OpenSauce.Inventory.Allergen

  defp staff, do: OpenSauce.DataCase.staff_actor()

  defp create_allergen(name) do
    Allergen
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create(actor: staff())
  end

  describe "allergen name validation" do
    test "accepts ASCII name" do
      assert {:ok, _} = create_allergen("Gluten")
    end

    test "accepts Japanese name" do
      assert {:ok, _} = create_allergen("小麦")
    end

    test "rejects invalid chars" do
      assert {:error, changeset} = create_allergen("Gluten@Free")
      assert inspect(changeset.errors) =~ "must match"
    end
  end
end
