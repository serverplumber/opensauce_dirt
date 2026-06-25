# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.CustomerLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view


  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- header --%>
      <div style="padding:12px 16px 14px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;">
          Customers
        </h1>
      </div>

      <%!-- list --%>
      <div id="customers" phx-update="stream" style="padding:0 16px 0;">
        <div :for={{dom_id, customer} <- @streams.customers} id={dom_id} class="jcard" style="cursor:pointer;">
          <.link navigate={~p"/manage/customers/#{customer.reference}"} style="display:flex;align-items:center;gap:12px;text-decoration:none;color:inherit;">
            <div style="flex:1;min-width:0;">
              <p style="font-size:15px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {customer.full_name}
              </p>
              <p :if={customer.company_name_nickname} style="font-size:12.5px;color:#9A9384;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {customer.company_name_nickname}
              </p>
              <p style="font-size:12px;color:#6E675A;margin-top:3px;">
                {garden_count_label(customer.garden_addresses)}
              </p>
            </div>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style="color:#6E675A;flex:0 0 auto;">
              <path d="M9 18l6-6-6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </.link>
        </div>
      </div>

      <p :if={@customer_count == 0} style="font-size:13.5px;color:#6E675A;text-align:center;padding:40px 0 100px;">
        No customers yet
      </p>

      <%!-- FAB --%>
      <.link navigate={~p"/manage/customers/new"}>
        <button class="fab" ontouchstart="" aria-label="New customer">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M12 5v14M5 12h14" stroke="#0C1F15" stroke-width="2.5" stroke-linecap="round"/>
          </svg>
        </button>
      </.link>

    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    customers =
      OpenSauce.CRM.list_customers!(
        actor: socket.assigns.current_member,
        tenant: socket.assigns.current_member.organisation_id,
        load: [:full_name, :garden_addresses]
      )

    {:ok,
     socket
     |> stream(:customers, customers)
     |> assign(:customer_count, length(customers))
     |> assign_new(:current_member, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Customers")
    |> assign(:main_bg, "bg-[#16140E]")
  end

  defp garden_count_label([]), do: "No gardens"
  defp garden_count_label([_]), do: "1 garden"
  defp garden_count_label(gardens), do: "#{length(gardens)} gardens"
end
