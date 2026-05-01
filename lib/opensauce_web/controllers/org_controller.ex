defmodule OpenSauceWeb.OrgController do
  use OpenSauceWeb, :controller

  alias OpenSauce.Accounts

  def pick(conn, %{"id" => org_id}) do
    user = conn.assigns.current_user

    case Accounts.get_member_by_user_and_organisation(user.id, org_id, authorize?: false) do
      {:ok, _member} ->
        conn
        |> put_session("organisation_id", org_id)
        |> redirect(to: ~p"/manage/overview")

      _ ->
        conn
        |> put_flash(:error, "You are not a member of that organisation")
        |> redirect(to: ~p"/org/pick")
    end
  end
end
