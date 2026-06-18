# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.ManageInventoryEditInteractionsLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OpenSauce.Inventory.Material

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      price: Decimal.new("1.00"),
      unit: :gram,
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: OpenSauce.DataCase.staff_actor())
  end

  @tag role: :staff
  test "edit material and save", %{conn: conn} do
    m = create_material!()
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/edit")

    params = %{"material" => %{"name" => m.name <> "X"}}

    view
    |> element("#material-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.sku}/details")
    assert render(view) =~ "Material updated successfully"
  end
end
