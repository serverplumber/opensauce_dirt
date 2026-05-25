defmodule OpenSauceWeb.LiveSettings do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use OpenSauceWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    if socket.assigns[:organisation] do
      {:cont, socket}
    else
      socket
      |> load_organisation()
      |> assign_timezone(session["timezone"])
      |> then(&{:cont, &1})
    end
  end

  defp load_organisation(socket) do
    org =
      OpenSauce.Accounts.get_organisation!(
        socket.assigns.current_member.organisation_id,
        authorize?: false
      )

    assign(socket, :organisation, org)
  end

  defp assign_timezone(socket, timezone) do
    assign(socket, :time_zone, timezone)
  end
end
