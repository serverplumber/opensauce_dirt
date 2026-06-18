defmodule OpenSauceWeb.InvoiceLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:100px;">
      <%!-- header --%>
      <div style="padding:12px 16px 14px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;">
          Invoices
        </h1>
        <p style="font-size:13px;color:#9A9384;margin-top:3px;">
          Billing across jobs and engagements.
        </p>
      </div>

      <%!-- draft section --%>
      <div :if={@drafts != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          draft
        </p>
        <div style="display:flex;flex-direction:column;gap:10px;">
          <.invoice_card :for={inv <- @drafts} invoice={inv} currency={@organisation.currency} />
        </div>
      </div>

      <%!-- sent section --%>
      <div :if={@sent != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          sent
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.invoice_card :for={inv <- @sent} invoice={inv} currency={@organisation.currency} />
        </div>
      </div>

      <%!-- paid section --%>
      <div :if={@paid != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          paid
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.invoice_card :for={inv <- @paid} invoice={inv} currency={@organisation.currency} />
        </div>
      </div>

      <%!-- voided section --%>
      <div :if={@voided != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          void
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.invoice_card :for={inv <- @voided} invoice={inv} currency={@organisation.currency} />
        </div>
      </div>

      <%!-- empty state --%>
      <div
        :if={@drafts == [] and @sent == [] and @paid == [] and @voided == []}
        style="padding:60px 16px;text-align:center;"
      >
        <p style="font-size:15px;color:#6E675A;">No invoices yet.</p>
        <p style="font-size:13px;color:#6E675A;margin-top:6px;">
          Tap + to create your first invoice.
        </p>
      </div>

      <%!-- FAB --%>
      <.link patch={~p"/manage/invoices/new"}>
        <button
          type="button"
          ontouchstart=""
          style="position:fixed;bottom:90px;right:20px;width:52px;height:52px;border-radius:50%;background:#54B57E;border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;box-shadow:0 4px 16px rgba(84,181,126,0.35);z-index:50;"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
            <path d="M12 5v14M5 12h14" stroke="#0C1F15" stroke-width="2.5" stroke-linecap="round" />
          </svg>
        </button>
      </.link>

      <%!-- new invoice bottom sheet --%>
      <div
        :if={@live_action == :new}
        class="fixed inset-0 z-[60] flex items-end justify-center"
        role="dialog"
        aria-label="New Invoice"
      >
        <div class="absolute inset-0 bg-black/50" phx-click={JS.patch(~p"/manage/invoices")} aria-hidden="true" />
        <div
          class="relative w-full max-w-lg mobile-scroll"
          style="background:#211E16;border-top:1.5px solid rgba(52,48,37,0.58);border-radius:20px 20px 0 0;max-height:92svh;overflow-y:auto;padding-bottom:max(1.5rem,env(safe-area-inset-bottom));"
        >
          <div style="padding:16px 16px 4px;display:flex;align-items:center;justify-content:space-between;">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:18px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
              New Invoice
            </p>
            <.link patch={~p"/manage/invoices"}>
              <button type="button" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
                <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </.link>
          </div>
          <.live_component
            module={OpenSauceWeb.InvoiceLive.FormComponent}
            id={:new}
            current_member={@current_member}
            organisation={@organisation}
            invoice={nil}
            patch={~p"/manage/invoices"}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :invoice, :map, required: true
  attr :currency, :string, required: true

  defp invoice_card(assigns) do
    ~H"""
    <.link navigate={~p"/manage/invoices/#{@invoice.id}"}>
      <div
        style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px 16px;display:flex;align-items:center;justify-content:space-between;gap:12px;"
        ontouchstart=""
      >
        <div style="min-width:0;flex:1;">
          <p style="font-size:15px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {customer_name(@invoice)}
          </p>
          <div style="display:flex;align-items:center;gap:6px;margin-top:3px;">
            <span style="font-family:monospace;font-size:11px;color:#6E675A;">{@invoice.reference}</span>
            <span style="color:#6E675A;">·</span>
            <span style="font-size:12px;color:#9A9384;">{format_date(@invoice.issued_on)}</span>
          </div>
        </div>
        <div style="display:flex;align-items:center;gap:8px;flex-shrink:0;">
          <span style="font-size:15px;font-weight:700;color:#F4EFE2;">
            {format_money(@currency, @invoice.amount)}
          </span>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M9 6l6 6-6 6" stroke="#6E675A" stroke-width="2" stroke-linecap="round" />
          </svg>
        </div>
      </div>
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, drafts: [], sent: [], paid: [], voided: [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, "Invoices")
      |> assign(:main_bg, "bg-[#16140E]")
      |> load_invoices()

    {:noreply, Navigation.assign(socket, :invoices, [Navigation.root(:invoices)])}
  end

  @impl true
  def handle_info({OpenSauceWeb.InvoiceLive.FormComponent, {:saved, _invoice}}, socket) do
    {:noreply, load_invoices(socket)}
  end

  defp load_invoices(socket) do
    member = socket.assigns.current_member

    all =
      CRM.list_invoices!(
        actor: member,
        tenant: member.organisation_id,
        load: [:customer]
      )

    socket
    |> assign(:drafts, Enum.filter(all, &(&1.status == :draft)))
    |> assign(:sent, Enum.filter(all, &(&1.status == :sent)))
    |> assign(:paid, Enum.filter(all, &(&1.status == :paid)))
    |> assign(:voided, Enum.filter(all, &(&1.status == :void)))
  end

  defp customer_name(%{customer: %{first_name: f, last_name: l}}), do: "#{f} #{l}"
  defp customer_name(_), do: "Unknown customer"
end
