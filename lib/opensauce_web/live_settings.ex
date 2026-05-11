defmodule OpenSauceWeb.LiveSettings do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use OpenSauceWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    if socket.assigns[:settings] do
      {:cont, socket}
    else
      socket
      |> load_settings()
      |> assign_timezone(session["timezone"])
      |> then(&{:cont, &1})
    end
  end

  defp load_settings(socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    settings =
      case OpenSauce.Settings.get_settings(opts) do
        {:ok, settings} ->
          settings

        {:error, _} ->
          OpenSauce.Settings.init!(opts)
      end

    assign(socket, :settings, settings)
  end

  defp assign_timezone(socket, timezone) do
    assign(socket, :time_zone, timezone)
  end
end
