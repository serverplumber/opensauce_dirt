defmodule OpenSauceWeb.ManageSettingsInteractionsLiveTest do
  use OpenSauceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :owner
  test "organisation settings can be saved", %{conn: conn, member: member} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

    view
    |> element("#org-form")
    |> render_submit(%{"organisation" => %{"tax_rate" => "0.15"}})

    org = OpenSauce.Accounts.get_organisation!(member.organisation_id, authorize?: false)
    assert Decimal.equal?(org.tax_rate, Decimal.new("0.15"))
  end
end
