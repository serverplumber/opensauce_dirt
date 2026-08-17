defmodule OpenSauceWeb.InvoiceLive.Edit do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:40px;">
      <%!-- top bar --%>
      <div style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;">
        <.link navigate={~p"/manage/invoices/#{@invoice.id}"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </button>
        </.link>
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:20px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
          Edit Invoice
        </h1>
        <span style="font-family:monospace;font-size:13px;color:#6E675A;margin-left:4px;">
          #{format_invoice_number(@invoice.invoice_number)}
        </span>
      </div>

      <.live_component
        module={OpenSauceWeb.InvoiceLive.FormComponent}
        id={@invoice.id}
        current_member={@current_member}
        organisation={@organisation}
        invoice={@invoice}
        patch={~p"/manage/invoices/#{@invoice.id}/edit"}
      />
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    member = socket.assigns.current_member

    invoice =
      CRM.get_invoice_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [:customer]
      )

    {:ok,
     socket
     |> assign(:invoice, invoice)
     |> assign(:page_title, "Edit Invoice")
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({OpenSauceWeb.InvoiceLive.FormComponent, {:saved, invoice}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manage/invoices/#{invoice.id}", replace: true)}
  end

  defp format_invoice_number(n), do: String.pad_leading(Integer.to_string(n), 4, "0")
end
