defmodule OpenSauceWeb.InvoiceLive.New do
  @moduledoc false
  use OpenSauceWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:40px;">
      <%!-- top bar --%>
      <div style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;">
        <.link navigate={~p"/manage/invoices"}>
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
          New Invoice
        </h1>
      </div>

      <.live_component
        module={OpenSauceWeb.InvoiceLive.FormComponent}
        id={:new}
        current_member={@current_member}
        organisation={@organisation}
        invoice={nil}
        patch={~p"/manage/invoices/new"}
      />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "New Invoice", main_bg: "bg-[#16140E]")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({OpenSauceWeb.InvoiceLive.FormComponent, {:saved, invoice}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manage/invoices/#{invoice.id}")}
  end
end
