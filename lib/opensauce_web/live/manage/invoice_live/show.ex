defmodule OpenSauceWeb.InvoiceLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import Ash.Query

  alias Decimal, as: D
  alias OpenSauce.Accounts
  alias OpenSauce.CRM
  alias OpenSauce.Portal
  alias OpenSauce.Work

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:120px;">
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
        <p style="flex:1;font-family:monospace;font-size:14px;color:#6E675A;">
          #{format_invoice_number(@invoice.invoice_number)}
        </p>
        <span style={"#{status_badge_style(@invoice.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
          {status_label(@invoice.status)}
        </span>
      </div>

      <%!-- invoice document --%>
      <div style="padding:0 16px 16px;">
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:20px;overflow:hidden;">

          <%!-- org header --%>
          <div style="padding:20px 20px 16px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#54B57E;">
              {@organisation.name}
            </p>
            <p :if={@organisation.legal_name} style="font-size:12px;color:#9A9384;margin-top:2px;">
              {@organisation.legal_name}
            </p>
            <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
              <span :if={@organisation.phone} style="font-size:12px;color:#6E675A;">{@organisation.phone}</span>
              <span :if={@organisation.phone && @organisation.website} style="color:#6E675A;">·</span>
              <span :if={@organisation.website} style="font-size:12px;color:#6E675A;">{@organisation.website}</span>
              <span :if={@organisation.contact_email} style="color:#6E675A;">·</span>
              <span :if={@organisation.contact_email} style="font-size:12px;color:#6E675A;">{@organisation.contact_email}</span>
            </div>
          </div>

          <%!-- invoice meta + bill to --%>
          <div style="padding:16px 20px;border-bottom:1px solid rgba(52,48,37,0.58);display:flex;gap:20px;align-items:flex-start;">
            <%!-- left: invoice number + dates --%>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Invoice</p>
              <p style="font-family:monospace;font-size:18px;font-weight:700;color:#F4EFE2;margin-top:2px;">
                #{format_invoice_number(@invoice.invoice_number)}
              </p>
              <div style="margin-top:10px;display:flex;flex-direction:column;gap:4px;">
                <div style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:#6E675A;width:44px;">Issued</span>
                  <span style="font-size:11px;color:#F4EFE2;">{format_date(@invoice.issued_on)}</span>
                </div>
                <div :if={@invoice.due_on} style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:#6E675A;width:44px;">Due</span>
                  <span style="font-size:11px;color:#F4EFE2;">{format_date(@invoice.due_on)}</span>
                </div>
              </div>
            </div>
            <%!-- right: bill to --%>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Bill To</p>
              <p style="font-size:14px;font-weight:600;color:#F4EFE2;margin-top:4px;">{customer_name(@invoice)}</p>
              <div :if={billing_address = @invoice.customer && @invoice.customer.billing_address} style="margin-top:4px;">
                <p :if={billing_address.street} style="font-size:12px;color:#9A9384;">{billing_address.street}</p>
                <p style="font-size:12px;color:#9A9384;">
                  {[billing_address.city, billing_address.province, billing_address.zip] |> Enum.reject(&is_nil/1) |> Enum.join(", ")}
                </p>
              </div>
              <p :if={@invoice.customer && @invoice.customer.email} style="font-size:12px;color:#6E675A;margin-top:4px;">
                {@invoice.customer.email}
              </p>
            </div>
          </div>

          <%!-- line items --%>
          <div style="padding:16px 20px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:10px;">
              <span style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Description</span>
              <span style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Amount</span>
            </div>
            <div style="display:flex;flex-direction:column;">
              <%!-- engagement groups --%>
              <div :for={group_items <- @item_groups}>
                <% eng = Enum.find(group_items, &(&1["type"] == "engagement")) %>
                <% jobs = Enum.filter(group_items, &(&1["type"] == "job")) %>
                <%!-- engagement fee row --%>
                <div
                  :if={eng}
                  style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:8px 0;border-bottom:1px solid rgba(52,48,37,0.4);"
                >
                  <p style="flex:1;font-size:13px;font-weight:700;color:#F4EFE2;min-width:0;">{eng["label"]}</p>
                  <span
                    :if={eng["amount"] && eng["amount"] != "0.00"}
                    style="font-size:13px;font-weight:700;color:#F4EFE2;white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                  >
                    {format_money(@organisation.currency, eng["amount"])}
                  </span>
                </div>
                <%!-- job rows --%>
                <div
                  :for={job <- jobs}
                  style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:7px 0 7px 12px;border-bottom:1px solid rgba(52,48,37,0.3);"
                >
                  <div style="flex:1;min-width:0;">
                    <p style="font-size:12.5px;color:#9A9384;">{job["label"]}</p>
                    <p :if={job["date"]} style="font-size:11px;color:#6E675A;margin-top:2px;">{job["date"]}</p>
                  </div>
                  <span
                    :if={job["amount"] && job["amount"] != "0.00"}
                    style="font-size:12.5px;color:#9A9384;white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                  >
                    {format_money(@organisation.currency, job["amount"])}
                  </span>
                </div>
              </div>
              <%!-- ungrouped / legacy flat items --%>
              <div
                :for={item <- @ungrouped_items}
                style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:8px 0;border-bottom:1px solid rgba(52,48,37,0.4);"
              >
                <div style="flex:1;min-width:0;">
                  <p style="font-size:13px;color:#F4EFE2;">{item["label"]}</p>
                  <p :if={item["date"]} style="font-size:11px;color:#6E675A;margin-top:2px;">{item["date"]}</p>
                </div>
                <span
                  :if={item["amount"] && item["amount"] != "0.00"}
                  style="font-size:13px;color:#F4EFE2;white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                >
                  {format_money(@organisation.currency, item["amount"])}
                </span>
              </div>
              <div :if={@item_groups == [] && @ungrouped_items == []} style="padding:12px 0;text-align:center;">
                <p style="font-size:13px;color:#6E675A;">No line items.</p>
              </div>
            </div>
          </div>

          <%!-- totals --%>
          <div style="padding:0 20px 20px;">
            <%!-- subtotal row (only shown when there are taxes) --%>
            <div
              :if={@tax_rates != [] && @organisation.tax_mode == :exclusive}
              style="display:flex;justify-content:space-between;padding:6px 0;"
            >
              <span style="font-size:12px;color:#9A9384;">Subtotal</span>
              <span style="font-size:12px;color:#9A9384;font-variant-numeric:tabular-nums;">
                {format_money(@organisation.currency, @invoice.amount)}
              </span>
            </div>

            <%!-- tax lines (exclusive mode only) --%>
            <div :for={tax <- @tax_lines} style="display:flex;justify-content:space-between;padding:6px 0;">
              <span style="font-size:12px;color:#9A9384;">
                {tax.name} ({tax.rate |> D.normalize() |> D.to_string()}%)
                <span :if={tax.registration_number} style="color:#6E675A;font-size:11px;">· {tax.registration_number}</span>
              </span>
              <span style="font-size:12px;color:#9A9384;font-variant-numeric:tabular-nums;">
                {format_money(@organisation.currency, tax.amount)}
              </span>
            </div>

            <%!-- total --%>
            <div style="display:flex;justify-content:space-between;align-items:baseline;padding-top:10px;margin-top:4px;border-top:1px solid rgba(52,48,37,0.58);">
              <span style="font-size:14px;font-weight:700;color:#F4EFE2;letter-spacing:0.02em;">Total</span>
              <span style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;color:#54B57E;letter-spacing:-0.02em;font-variant-numeric:tabular-nums;">
                {format_money(@organisation.currency, @grand_total)}
              </span>
            </div>

            <p :if={@organisation.tax_mode == :inclusive && @tax_lines != []} style="font-size:11px;color:#6E675A;margin-top:6px;text-align:right;">
              Includes {Enum.map_join(@tax_lines, ", ", fn t -> "#{D.normalize(t.rate) |> D.to_string()}% #{t.name}" end)}
            </p>
          </div>

          <%!-- payment info --%>
          <div
            :if={@organisation.payment_info}
            style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);"
          >
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">
              Payment
            </p>
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@organisation.payment_info}</p>
          </div>

          <%!-- notes --%>
          <div
            :if={@invoice.notes}
            style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);"
          >
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">
              Notes
            </p>
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@invoice.notes}</p>
          </div>

          <%!-- invoice terms --%>
          <div
            :if={@organisation.invoice_terms}
            style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);"
          >
            <p style="font-size:11px;color:#6E675A;white-space:pre-line;">{@organisation.invoice_terms}</p>
          </div>

          <%!-- footer --%>
          <div
            :if={@organisation.invoice_footer}
            style="padding:10px 20px;border-top:1px solid rgba(52,48,37,0.58);text-align:center;"
          >
            <p style="font-size:11px;color:#6E675A;">{@organisation.invoice_footer}</p>
          </div>

        </div>
      </div>

      <%!-- sticky action buttons --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;display:flex;flex-direction:column;gap:8px;">
        <%!-- send + mark sent (always visible; mark sent also sends) --%>
        <div style="display:flex;gap:8px;">
          <button
            type="button"
            phx-click="send_to_client"
            ontouchstart=""
            style="flex:1;background:rgba(84,181,126,0.08);border:1px solid rgba(84,181,126,0.3);border-radius:12px;padding:11px;font-size:14px;font-weight:600;color:#54B57E;cursor:pointer;"
          >
            Send to Client
          </button>
          <button
            :if={@invoice.status in [:draft, :sent]}
            type="button"
            phx-click="mark_paid"
            ontouchstart=""
            style="flex:1;background:#54B57E;border:none;border-radius:12px;padding:11px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
          >
            Paid
          </button>
        </div>
        <button
          :if={@invoice.status in [:draft, :sent]}
          type="button"
          phx-click="void_invoice"
          ontouchstart=""
          style="width:100%;background:rgba(232,126,126,0.08);border:1px solid rgba(232,126,126,0.2);border-radius:12px;padding:9px;font-size:13px;font-weight:600;color:#E87E7E;cursor:pointer;"
        >
          Void Invoice
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    member = socket.assigns.current_member
    invoice = load_invoice(id, member)
    tax_rates = load_tax_rates(member)
    {tax_lines, grand_total} = compute_taxes(invoice.amount, tax_rates, socket.assigns.organisation.tax_mode)
    {item_groups, ungrouped_items} = group_line_items(invoice.line_items)

    socket =
      socket
      |> assign(:invoice, invoice)
      |> assign(:tax_rates, tax_rates)
      |> assign(:tax_lines, tax_lines)
      |> assign(:grand_total, grand_total)
      |> assign(:item_groups, item_groups)
      |> assign(:ungrouped_items, ungrouped_items)
      |> assign(:page_title, "Invoice ##{format_invoice_number(invoice.invoice_number)}")
      |> assign(:main_bg, "bg-[#16140E]")

    {:noreply, socket}
  end

  @impl true
  def handle_event("mark_paid", _params, socket) do
    member = socket.assigns.current_member
    {:ok, _} = CRM.mark_invoice_paid(socket.assigns.invoice, actor: member, tenant: member.organisation_id)
    invoice = load_invoice(socket.assigns.invoice.id, member)

    customer = Ash.get!(CRM.Customer, invoice.customer_id, actor: member, tenant: member.organisation_id)
    Portal.send_invoice_receipt(customer, socket.assigns.organisation, invoice, socket.assigns.tax_lines, socket.assigns.grand_total)

    {:noreply, socket |> assign(:invoice, invoice) |> put_flash(:info, "Marked paid — receipt sent to #{customer.email}.")}
  end

  @impl true
  def handle_event("send_to_client", _params, socket) do
    member = socket.assigns.current_member
    invoice = socket.assigns.invoice

    # Advance draft → sent before the customer ever sees it.
    invoice =
      if invoice.status == :draft do
        {:ok, sent} = CRM.mark_invoice_sent(invoice, actor: member, tenant: member.organisation_id)
        sent
      else
        invoice
      end

    invoice = load_invoice(invoice.id, member)
    customer = Ash.get!(CRM.Customer, invoice.customer_id, actor: member, tenant: member.organisation_id)

    {tax_lines, grand_total} =
      compute_taxes(invoice.amount, socket.assigns.tax_rates, socket.assigns.organisation.tax_mode)

    Portal.send_invoice_to_client(customer, socket.assigns.organisation, invoice, tax_lines, grand_total)

    {:noreply,
     socket
     |> assign(:invoice, invoice)
     |> assign(:tax_lines, tax_lines)
     |> assign(:grand_total, grand_total)
     |> put_flash(:info, "Invoice sent to #{customer.email}.")}
  end

  @impl true
  def handle_event("void_invoice", _params, socket) do
    member = socket.assigns.current_member
    {:ok, _} = CRM.void_invoice(socket.assigns.invoice, actor: member, tenant: member.organisation_id)
    invoice = load_invoice(socket.assigns.invoice.id, member)
    {:noreply, assign(socket, :invoice, invoice)}
  end

  defp load_invoice(id, member) do
    CRM.get_invoice_by_id!(id,
      actor: member,
      tenant: member.organisation_id,
      load: [customer: [:billing_address]]
    )
  end

  defp load_tax_rates(member) do
    Accounts.list_tax_rates!(actor: member, tenant: member.organisation_id)
    |> Enum.sort_by(& &1.position)
  rescue
    _ -> []
  end

  defp compute_taxes(subtotal, tax_rates, :exclusive) do
    subtotal_d = parse_decimal(subtotal)

    {tax_lines, running} =
      Enum.map_reduce(tax_rates, subtotal_d, fn rate, acc ->
        base = if rate.is_compound, do: acc, else: subtotal_d
        amount = D.mult(base, D.div(rate.rate, D.new(100))) |> D.round(2)
        line = %{name: rate.name, rate: rate.rate, registration_number: rate.registration_number, amount: amount}
        {line, D.add(acc, amount)}
      end)

    tax_total = Enum.reduce(tax_lines, D.new(0), fn t, acc -> D.add(acc, t.amount) end)
    grand_total = D.add(subtotal_d, tax_total) |> D.round(2)
    {tax_lines, grand_total}
  end

  defp compute_taxes(subtotal, _tax_rates, _inclusive) do
    {[], parse_decimal(subtotal)}
  end

  defp group_line_items(items) do
    # Walk in order, collecting items into named groups or a flat ungrouped list.
    # Returns {[[item, ...], ...], [item, ...]} — groups list preserves insertion order.
    {groups_map, group_order, ungrouped} =
      Enum.reduce(items, {%{}, [], []}, fn item, {map, order, flat} ->
        case item["group_id"] do
          nil ->
            {map, order, flat ++ [item]}

          gid ->
            updated_map = Map.update(map, gid, [item], &(&1 ++ [item]))
            updated_order = if gid in order, do: order, else: order ++ [gid]
            {updated_map, updated_order, flat}
        end
      end)

    groups = Enum.map(group_order, &Map.get(groups_map, &1, []))
    {groups, ungrouped}
  end

  defp parse_decimal(nil), do: D.new(0)
  defp parse_decimal(%D{} = d), do: d
  defp parse_decimal(s) when is_binary(s) do
    case D.parse(s) do
      {d, ""} -> d
      _ -> D.new(0)
    end
  end

  defp customer_name(%{customer: %{first_name: f, last_name: l}}), do: "#{f} #{l}"
  defp customer_name(_), do: "Unknown customer"

  defp format_invoice_number(n), do: String.pad_leading(Integer.to_string(n), 4, "0")

  defp status_label(:draft), do: "draft"
  defp status_label(:sent), do: "sent"
  defp status_label(:paid), do: "paid"
  defp status_label(:void), do: "void"
  defp status_label(s), do: to_string(s)

  defp status_badge_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:sent), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_badge_style(:paid), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:void), do: "background:rgba(232,126,126,0.15);color:#E87E7E;"
  defp status_badge_style(_), do: "background:rgba(154,147,132,0.15);color:#9A9384;"
end
