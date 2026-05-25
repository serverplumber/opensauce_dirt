defmodule OpenSauceWeb.ManageSettingsInteractionsLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :owner
  test "organisation settings can be saved", %{conn: conn, member: member} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

    view
    |> element("#org-form")
    |> render_submit(%{"organisation" => %{"currency" => "USD"}})

    org = OpenSauce.Accounts.get_organisation!(member.organisation_id, authorize?: false)
    assert org.currency == :USD
  end
end
