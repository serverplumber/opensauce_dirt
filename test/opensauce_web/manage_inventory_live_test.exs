# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.ManageInventoryLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OpenSauce.Test.Factory
  alias OpenSauce.Operations

  describe "index and new" do
    @tag role: :staff
    test "renders inventory index for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/inventory")
      assert has_element?(view, "#materials")
    end

    @tag role: :staff
    test "renders new material modal and creates material", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/inventory/new")
      assert has_element?(view, "#material-form")

      params = %{
        "material" => %{
          "name" => "New Material",
          "sku" => "mat-" <> Ecto.UUID.generate(),
          "price" => "2.50",
          "unit" => "gram",
          "minimum_stock" => "0",
          "maximum_stock" => "0"
        }
      }

      view
      |> element("#material-form")
      |> render_submit(params)

      assert_patch(view, ~p"/manage/inventory")
      assert render(view) =~ "Material created successfully"
    end
  end

  describe "show tabs" do
    @tag role: :staff
    test "renders material details tab for staff", %{conn: conn, member: member} do
      material = Factory.create_material!(%{}, member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    @tag role: :staff
    test "renders stock tab for staff", %{conn: conn, member: member} do
      material = Factory.create_material!(%{}, member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/stock")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#inventory_movements")
    end

    @tag role: :staff
    test "renders edit modal for staff", %{conn: conn, member: member} do
      material = Factory.create_material!(%{}, member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/edit")
      assert has_element?(view, "#material-form")
    end

    @tag role: :staff
    test "renders adjust modal for staff", %{conn: conn, member: member} do
      material = Factory.create_material!(%{}, member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")
      assert has_element?(view, "#movement-form")
    end
  end

  describe "movement form" do
    defp create_material_with_stock!(qty, member) do
      venue = Factory.create_venue!(%{}, member)

      material =
        OpenSauce.Inventory.Material
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Stock Material",
          sku: "MAT-#{System.unique_integer([:positive])}",
          unit: :gram,
          price: Decimal.new("1.00"),
          minimum_stock: Decimal.new(0),
          maximum_stock: Decimal.new(0)
        })
        |> Ash.create!(actor: member, tenant: member.organisation_id)

      lot =
        OpenSauce.Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: "LOT-#{System.unique_integer([:positive])}",
          material_id: material.id,
          venue_id: venue.id
        })
        |> Ash.create!(actor: member, tenant: member.organisation_id)

      OpenSauce.Inventory.adjust_stock!(
        %{quantity: Decimal.new(qty), reason: "seed", material_id: material.id, lot_id: lot.id},
        actor: member,
        tenant: member.organisation_id
      )

      Ash.reload!(material, load: [:current_stock], actor: member, tenant: member.organisation_id)
    end

    @tag role: :staff
    test "subtract mode creates a negative movement", %{conn: conn, member: member} do
      material = create_material_with_stock!("100", member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")

      view |> element("button[phx-value-mode=subtract]") |> render_click()

      view
      |> form("#movement-form", %{"movement" => %{"quantity" => "30", "reason" => "test sub"}})
      |> render_submit()

      assert_patch(view, ~p"/manage/inventory/#{material.sku}/stock")

      reloaded =
        Ash.load!(
          OpenSauce.Inventory.get_material_by_id!(material.id, actor: member, tenant: member.organisation_id),
          :current_stock,
          actor: member,
          tenant: member.organisation_id
        )

      assert Decimal.equal?(reloaded.current_stock, Decimal.new("70"))
    end

    @tag role: :staff
    test "decimal quantity round-trips correctly", %{conn: conn, member: member} do
      material = create_material_with_stock!("50", member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")

      view
      |> form("#movement-form", %{"movement" => %{"quantity" => "22.5", "reason" => "decimal"}})
      |> render_submit()

      assert_patch(view, ~p"/manage/inventory/#{material.sku}/stock")

      reloaded =
        Ash.load!(
          OpenSauce.Inventory.get_material_by_id!(material.id, actor: member, tenant: member.organisation_id),
          :current_stock,
          actor: member,
          tenant: member.organisation_id
        )

      assert Decimal.equal?(reloaded.current_stock, Decimal.new("72.5"))
    end

    @tag role: :staff
    test "subtract below zero shows red preview without clamping", %{conn: conn, member: member} do
      material = create_material_with_stock!("10", member)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")

      view |> element("button[phx-value-mode=subtract]") |> render_click()

      html =
        view
        |> form("#movement-form", %{"movement" => %{"quantity" => "50"}})
        |> render_change()

      assert html =~ "text-red-600"
      assert html =~ "-40"
    end
  end
end
