defmodule OpenSauceWeb.PortalAuth do
  @moduledoc false

  import Phoenix.Component

  def on_mount(:require_customer, _params, session, socket) do
    with customer_id when is_binary(customer_id) <- session["portal_customer_id"],
         org_id when is_binary(org_id) <- session["portal_org_id"],
         customer <- Ash.get!(OpenSauce.CRM.Customer, customer_id, authorize?: false, tenant: org_id),
         org <- OpenSauce.Accounts.get_organisation!(org_id, authorize?: false) do
      socket =
        socket
        |> assign(:current_customer, customer)
        |> assign(:portal_org_id, org_id)
        |> assign(:organisation, org)

      {:cont, socket}
    else
      _ -> {:halt, Phoenix.LiveView.redirect(socket, to: "/c/expired")}
    end
  end
end
