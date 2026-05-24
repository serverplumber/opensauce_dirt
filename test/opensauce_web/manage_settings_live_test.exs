defmodule OpenSauceWeb.ManageSettingsLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "admin access" do
    @tag role: :owner
    test "renders settings index for admin", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#org-form")
    end

    @tag role: :owner
    test "renders general tab for admin", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#org-form")
    end
  end

  describe "unauthenticated access" do
    test "redirects settings index to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/manage/settings")
    end
  end
end
