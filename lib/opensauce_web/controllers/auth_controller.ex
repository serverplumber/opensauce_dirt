defmodule OpenSauceWeb.AuthController do
  use OpenSauceWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias OpenSauce.Accounts

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> dispatch_after_auth(user)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Invalid or expired sign-in link")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:opensauce)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: ~p"/sign-in")
  end

  def redeem_magic_link(conn, %{"token" => token}) do
    result =
      OpenSauce.Accounts.User
      |> Ash.Query.for_read(:sign_in_with_magic_link, %{token: token})
      |> Ash.read_one(authorize?: false)

    case result do
      {:ok, user} when not is_nil(user) ->
        conn
        |> store_in_session(user)
        |> dispatch_after_auth(user)

      _ ->
        conn
        |> put_flash(:error, "Invalid or expired sign-in link")
        |> redirect(to: ~p"/sign-in")
    end
  end

  def redeem_magic_link(conn, _params) do
    conn
    |> put_flash(:error, "Missing sign-in token")
    |> redirect(to: ~p"/sign-in")
  end

  defp dispatch_after_auth(conn, user) do
    case Accounts.list_memberships_for_user(user.id, authorize?: false) do
      {:ok, []} ->
        conn
        |> put_flash(:info, "Welcome — let's set up your organisation.")
        |> redirect(to: ~p"/org/new")

      {:ok, [membership]} ->
        conn
        |> put_session("organisation_id", membership.organisation_id)
        |> put_flash(:info, "You are now signed in")
        |> redirect(to: ~p"/manage/jobs")

      {:ok, _many} ->
        conn
        |> put_flash(:info, "You are now signed in")
        |> redirect(to: ~p"/org/pick")

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong loading your account")
        |> redirect(to: ~p"/sign-in")
    end
  end
end
