defmodule OpenSauceWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating members in LiveViews.

  The actor for all Ash domain calls is `OrganisationMember`, not `User`.
  `current_user` (User) remains on the socket for AshAuthentication internals only.
  `current_member` (OrganisationMember) is the actor passed to every domain call.
  """

  use OpenSauceWeb, :verified_routes

  import Phoenix.Component

  alias OpenSauce.Accounts

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_member, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    {:cont, assign_member_if_possible(socket, nil)}
  end

  # Any authenticated member regardless of role.
  def on_mount(:live_member_required, _params, session, socket) do
    case load_member(socket, session) do
      {:ok, member} -> {:cont, assign(socket, :current_member, member)}
      :no_org -> {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/org/pick")}
      :error -> {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Staff, managers, and owners — excludes :readonly.
  def on_mount(:live_staff_required, _params, session, socket) do
    case load_member(socket, session) do
      {:ok, %{role: role} = member} when role in [:staff, :manager, :owner] ->
        {:cont, assign(socket, :current_member, member)}

      {:ok, _} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      :no_org ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/org/pick")}

      :error ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Managers and owners only.
  def on_mount(:live_manager_required, _params, session, socket) do
    case load_member(socket, session) do
      {:ok, %{role: role} = member} when role in [:manager, :owner] ->
        {:cont, assign(socket, :current_member, member)}

      {:ok, _} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      :no_org ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/org/pick")}

      :error ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # --

  defp load_member(socket, session) do
    with %{id: user_id} <- socket.assigns[:current_user],
         org_id when is_binary(org_id) <- session["organisation_id"],
         {:ok, member} <- Accounts.get_member_by_user_and_organisation(user_id, org_id) do
      {:ok, member}
    else
      _ ->
        if socket.assigns[:current_user], do: :no_org, else: :error
    end
  end

  defp assign_member_if_possible(socket, default) do
    assign(socket, :current_member, default)
  end
end
