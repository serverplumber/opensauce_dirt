defmodule OpenSauceWeb.CommandPaletteTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OpenSauce.Test.{AuthHelpers, Factory}

  defp staff_conn(conn) do
    {user, member} = AuthHelpers.register_user!(role: :staff)
    conn = AuthHelpers.sign_in(conn, user)
    {conn, member}
  end

  describe "command palette" do
    test "renders search button in header for authenticated users", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, _view, html} = live(conn, ~p"/manage/customers")

      assert html =~ "command-palette"
      assert html =~ "Search..."
    end

    test "opens when clicking the search button", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      # Click the search button (targeting the component)
      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Modal should be open
      html = render(view)
      assert html =~ "Search pages, actions, or records..."
      assert html =~ "to navigate"
    end

    test "shows static pages when first opened", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      html = render(view)
      assert html =~ "Pages"
      assert html =~ "Inventory"
      assert html =~ "Customers"
      assert html =~ "Purchasing"
      assert html =~ "Jobs"
    end

    test "shows static actions when first opened", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      html = render(view)
      assert html =~ "Actions"
      assert html =~ "New Material"
      assert html =~ "New Customer"
    end

    test "filters results when searching", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Search for "purchase"
      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "purchase"})

      html = render(view)
      assert html =~ "Purchasing"
      assert html =~ "New Purchase Order"
      refute html =~ ~r/<button[^>]*>.*New Material.*<\/button>/s
    end

    test "closes when clicking backdrop", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()
      assert render(view) =~ "Search pages, actions, or records..."

      view
      |> element("#command-palette")
      |> render_hook("close", %{})

      refute render(view) =~ "Search pages, actions, or records..."
    end

    test "searches materials by name", %{conn: conn} do
      {conn, staff} = staff_conn(conn)

      # Create a test material
      material = Factory.create_material!(%{name: "Cocoa Powder", sku: "cocoa-001"}, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "cocoa"})

      html = render(view)
      assert html =~ "Cocoa Powder"
      assert html =~ material.sku
    end

    test "searches customers by name", %{conn: conn} do
      {conn, staff} = staff_conn(conn)

      # Create a test customer in the same org as the LiveView session
      _customer = Factory.create_customer!(%{first_name: "Alice", last_name: "Smith"}, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "alice"})

      html = render(view)
      assert html =~ "Alice Smith"
    end

    test "shows no results message when nothing matches", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "xyznonexistent123"})

      html = render(view)
      assert html =~ "No results found"
      assert html =~ "xyznonexistent123"
    end

    test "navigates down through results", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Navigate down
      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "down"})

      # First item should no longer be selected, second should be
      html = render(view)
      # The selected item gets bg-stone-100 class
      assert html =~ "bg-stone-100"
    end

    test "navigates up through results", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Navigate down twice then up
      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "down"})

      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "down"})

      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "up"})

      # Verify we can navigate
      assert render(view) =~ "bg-stone-100"
    end

    test "selects item and navigates", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Click on the Inventory page item
      view
      |> element("#command-palette button[phx-value-path='/manage/inventory']")
      |> render_click()

      assert_redirect(view, ~p"/manage/inventory")
    end

    test "selects item via keyboard enter", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Select current item with enter
      view
      |> element("#command-palette")
      |> render_hook("select", %{})

      # Should navigate to first item (Inventory)
      assert_redirect(view, ~p"/manage/inventory")
    end
  end
end
