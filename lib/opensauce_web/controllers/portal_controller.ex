defmodule OpenSauceWeb.PortalController do
  @moduledoc false
  use OpenSauceWeb, :controller

  alias OpenSauce.Accounts
  alias OpenSauce.CRM
  alias OpenSauce.Portal

  # Step 1: decode the resource token, fire the access email, show "check your email".
  def view(conn, %{"token" => token}) do
    case Portal.verify_resource_token(token) do
      {:ok, %{org_id: org_id, customer_id: customer_id, type: type, id: resource_id}} ->
        customer = Ash.get!(CRM.Customer, customer_id, authorize?: false, tenant: org_id)
        org = Accounts.get_organisation!(org_id, authorize?: false)
        Portal.send_access_link(customer, org, type, resource_id)
        render(conn, :check_email, org_name: org.name)

      {:error, _} ->
        render(conn, :invalid_link, [])
    end
  end

  # Step 2: decode the access token, write session, redirect into portal.
  def access(conn, %{"token" => token}) do
    case Portal.verify_access_token(token) do
      {:ok, %{org_id: org_id, customer_id: customer_id, type: type, id: resource_id}} ->
        conn
        |> put_session("portal_customer_id", customer_id)
        |> put_session("portal_org_id", org_id)
        |> redirect(to: portal_path(type, resource_id))

      {:error, _} ->
        render(conn, :invalid_link, [])
    end
  end

  def expired(conn, _params), do: render(conn, :invalid_link, [])

  defp portal_path("invoice", id), do: "/c/invoice/#{id}"
  defp portal_path("estimate", id), do: "/c/estimate/#{id}"
end
