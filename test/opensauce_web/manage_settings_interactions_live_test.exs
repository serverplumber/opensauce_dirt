defmodule OpenSauceWeb.ManageSettingsInteractionsLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :owner
  test "general settings can be saved", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

    params = %{"settings" => %{"tax_rate" => "0.05"}}

    view
    |> element("#settings-form")
    |> render_submit(params)

    assert render(view) =~ "Settings updated successfully"
  end

end
