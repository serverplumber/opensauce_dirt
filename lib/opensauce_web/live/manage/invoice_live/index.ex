defmodule OpenSauceWeb.InvoiceLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:100px;">
      <%!-- header --%>
      <div style="padding:12px 16px 14px;">
        <div :if={@customer_filter} style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
          <.link navigate={~p"/manage/invoices"}>
            <button
              type="button"
              ontouchstart=""
              style="color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                <path
                  d="M19 12H5M12 19l-7-7 7-7"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
            </button>
          </.link>
          <span style="font-size:12px;color:#9A9384;">
            {@customer_filter.first_name} {@customer_filter.last_name}
          </span>
        </div>
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;">
          Invoices
        </h1>
        <p :if={!@customer_filter} style="font-size:13px;color:#9A9384;margin-top:3px;">
          Billing across jobs and engagements.
        </p>
      </div>

      <%!-- draft section --%>
      <div :if={@drafts != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          draft
        </p>
        <div style="display:flex;flex-direction:column;gap:10px;">
          <.invoice_card
            :for={inv <- @drafts}
            invoice={inv}
            currency={@organisation.currency}
            return_to={@return_to}
          />
        </div>
      </div>

      <%!-- sent section --%>
      <div :if={@sent != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          sent
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.invoice_card
            :for={inv <- @sent}
            invoice={inv}
            currency={@organisation.currency}
            return_to={@return_to}
          />
        </div>
      </div>

      <%!-- paid section --%>
      <div :if={@paid != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          paid
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.invoice_card
            :for={inv <- @paid}
            invoice={inv}
            currency={@organisation.currency}
            return_to={@return_to}
          />
        </div>
      </div>

      <%!-- voided section --%>
      <div :if={@voided != []} style="padding:0 16px 16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          void
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.invoice_card
            :for={inv <- @voided}
            invoice={inv}
            currency={@organisation.currency}
            return_to={@return_to}
          />
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
      <.link
        :if={is_nil(@customer_filter) || @has_invoiceable_work}
        navigate={~p"/manage/invoices/new"}
      >
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
    </div>
    """
  end

  attr :invoice, :map, required: true
  attr :currency, :string, required: true
  attr :return_to, :string, required: true

  defp invoice_card(assigns) do
    ~H"""
    <.link navigate={~p"/manage/invoices/#{@invoice.id}?return_to=#{@return_to}"}>
      <div
        style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px 16px;display:flex;align-items:center;justify-content:space-between;gap:12px;"
        ontouchstart=""
      >
        <div style="min-width:0;flex:1;">
          <p style="font-size:15px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {customer_name(@invoice)}
          </p>
          <div style="display:flex;align-items:center;gap:6px;margin-top:3px;">
            <span style="font-family:monospace;font-size:11px;color:#6E675A;">
              #{format_invoice_number(@invoice.invoice_number)}
            </span>
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
    {:ok,
     assign(socket,
       drafts: [],
       sent: [],
       paid: [],
       voided: [],
       customer_filter: nil,
       has_invoiceable_work: true
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    member = socket.assigns.current_member
    customer_id = params["customer_id"]

    customer_filter =
      if customer_id do
        Ash.get!(CRM.Customer, customer_id, actor: member, tenant: member.organisation_id)
      end

    return_to =
      if customer_id,
        do: ~p"/manage/invoices?customer_id=#{customer_id}",
        else: ~p"/manage/invoices"

    uninvoiced_ids =
      [actor: member, tenant: member.organisation_id]
      |> CRM.list_customers_with_uninvoiced_jobs!()
      |> MapSet.new(& &1.id)

    has_invoiceable_work =
      not MapSet.equal?(uninvoiced_ids, MapSet.new()) and
        (is_nil(customer_filter) or MapSet.member?(uninvoiced_ids, customer_filter.id))

    socket =
      socket
      |> assign(:page_title, "Invoices")
      |> assign(:main_bg, "bg-[#16140E]")
      |> assign(:customer_filter, customer_filter)
      |> assign(:has_invoiceable_work, has_invoiceable_work)
      |> assign(:return_to, return_to)
      |> load_invoices(customer_id)

    {:noreply, socket}
  end

  defp load_invoices(socket, customer_id) do
    member = socket.assigns.current_member

    query =
      if customer_id do
        import Ash.Query

        filter(CRM.Invoice, customer_id == ^customer_id)
      else
        CRM.Invoice
      end

    all =
      Ash.read!(query,
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

  defp format_invoice_number(n), do: String.pad_leading(Integer.to_string(n), 4, "0")
end
