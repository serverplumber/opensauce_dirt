defmodule OpenSauceWeb.LiveShift do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]

  alias OpenSauce.Work

  def on_mount(:default, _params, _session, socket) do
    member = socket.assigns[:current_member]

    active_shift =
      if member do
        [actor: member, tenant: member.organisation_id]
        |> Work.find_active_shift!()
        |> List.first()
      end

    {:cont, assign(socket, :active_shift, active_shift)}
  end
end
