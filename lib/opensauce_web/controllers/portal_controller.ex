defmodule OpenSauceWeb.PortalController do
  @moduledoc false
  use OpenSauceWeb, :controller

  alias OpenSauce.Accounts
  alias OpenSauce.CRM
  alias OpenSauce.Portal

  plug :put_layout, false
  plug :put_root_layout, false

  # Step 1: decode the resource token, fire the access email, show "check your email".
  def view(conn, %{"token" => token}) do
    case Portal.verify_resource_token(token) do
      {:ok, %{org_id: org_id, customer_id: customer_id, type: type, id: resource_id}} ->
        customer = Ash.get!(CRM.Customer, customer_id, authorize?: false, tenant: org_id)
        org = Accounts.get_organisation!(org_id, authorize?: false)
        Portal.send_access_link(customer, org, type, resource_id)

        brand = OpenSauce.BrandTheme.scheme(org)

        render(conn, :check_email,
          org_name: org.name,
          accent: brand.primary,
          brand: brand
        )

      {:error, _} ->
        render(conn, :invalid_link, [])
    end
  end

  # Step 2: decode the access token, write session, redirect into portal.
  # IP and UA are captured here — the HTTP connection where the magic link was clicked.
  # By the time the client signs, we're in a LiveView WebSocket and can't read these directly.
  def access(conn, %{"token" => token}) do
    case Portal.verify_access_token(token) do
      {:ok, %{org_id: org_id, customer_id: customer_id, type: type, id: resource_id}} ->
        peer_ip = conn.remote_ip |> :inet.ntoa() |> to_string()
        user_agent = conn |> get_req_header("user-agent") |> List.first() || "unknown"

        conn
        |> put_session("portal_customer_id", customer_id)
        |> put_session("portal_org_id", org_id)
        |> put_session("portal_peer_ip", peer_ip)
        |> put_session("portal_user_agent", user_agent)
        |> redirect(to: portal_path(type, resource_id))

      {:error, _} ->
        render(conn, :invalid_link, [])
    end
  end

  def expired(conn, _params), do: render(conn, :invalid_link, [])

  defp portal_path("invoice", id), do: "/c/invoice/#{id}"
  defp portal_path("estimate", id), do: "/c/estimate/#{id}"
end
