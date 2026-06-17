defmodule OpenSauceWeb.LiveShift do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]

  alias OpenSauce.Orders

  def on_mount(:default, _params, _session, socket) do
    member = socket.assigns[:current_member]

    active_shift =
      if member do
        Orders.find_active_shift!(actor: member, tenant: member.organisation_id)
        |> List.first()
      end

    {:cont, assign(socket, :active_shift, active_shift)}
  end
end
