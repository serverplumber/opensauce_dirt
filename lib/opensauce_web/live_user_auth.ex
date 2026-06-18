# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

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

  # Any authenticated member regardless of role.
  def on_mount(:live_member_required, _params, session, socket) do
    case load_member(socket, session) do
      {:ok, member, user, memberships} ->
        {:cont, socket |> assign(:current_member, member) |> assign(:current_user, user) |> assign(:memberships, memberships)}
      :suspended -> {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
      :no_org -> {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/org/pick")}
      :error -> {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Staff, managers, and owners.
  def on_mount(:live_staff_required, _params, session, socket) do
    case load_member(socket, session) do
      {:ok, %{role: role} = member, user, memberships} when role in [:staff, :manager, :owner] ->
        {:cont, socket |> assign(:current_member, member) |> assign(:current_user, user) |> assign(:memberships, memberships)}

      {:ok, _, _, _} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      :suspended ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      :no_org ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/org/pick")}

      :error ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Managers and owners only.
  def on_mount(:live_manager_required, _params, session, socket) do
    case load_member(socket, session) do
      {:ok, %{role: role} = member, user, memberships} when role in [:manager, :owner] ->
        {:cont, socket |> assign(:current_member, member) |> assign(:current_user, user) |> assign(:memberships, memberships)}

      {:ok, _, _, _} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      :suspended ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      :no_org ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/org/pick")}

      :error ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # --

  defp load_member(socket, session) do
    with %{id: user_id} = raw_user <- socket.assigns[:current_user],
         org_id when is_binary(org_id) <- session["organisation_id"],
         {:ok, member} <- Accounts.get_member_by_user_and_organisation(user_id, org_id) do
      if member.status == :suspended do
        :suspended
      else
        user = Ash.load!(raw_user, [:initials], authorize?: false, domain: Accounts)
        memberships = Accounts.list_memberships_for_user!(user_id, authorize?: false)
        {:ok, member, user, memberships}
      end
    else
      _ ->
        if socket.assigns[:current_user], do: :no_org, else: :error
    end
  end
end
