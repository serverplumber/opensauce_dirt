defmodule OpenSauceWeb.InvoiceLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias Decimal, as: D
  alias OpenSauce.Accounts
  alias OpenSauce.BrandTheme
  alias OpenSauce.CRM
  alias OpenSauce.Portal

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:var(--s-text,#F4EFE2);-webkit-font-smoothing:antialiased;padding-bottom:120px;">
      <%!-- top bar --%>
      <div style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;">
        <.link navigate={@return_to}>
          <button
            type="button"
            ontouchstart=""
            style="color:var(--s-muted,#9A9384);background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </button>
        </.link>
        <p style="flex:1;font-family:monospace;font-size:14px;color:var(--s-dim,#6E675A);">
          #{format_invoice_number(@invoice.invoice_number)}
        </p>
        <.link :if={@invoice.status != :paid} navigate={~p"/manage/invoices/#{@invoice.id}/edit"}>
          <button
            type="button"
            ontouchstart=""
            style="color:var(--s-muted,#9A9384);background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              />
            </svg>
          </button>
        </.link>
        <span style={"#{status_badge_style(@invoice.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
          {status_label(@invoice.status)}
        </span>
      </div>

      <%!-- invoice document — --s-* vars render it in the org's chosen mode,
           exactly as the customer sees it; staff chrome outside stays soil --%>
      <div style="padding:0 16px 16px;">
        <% brand = BrandTheme.scheme(@display_org) %>
        <div style={"background:#{brand.paper};border:1px solid #{BrandTheme.rgba(brand.border, 0.58)};border-radius:20px;overflow:hidden;color:#{brand.text};--s-bg:#{brand.bg};--s-paper:#{brand.paper};--s-border:#{BrandTheme.rgba(brand.border, 0.58)};--s-text:#{brand.text};--s-muted:#{brand.muted};--s-dim:#{brand.dim};"}>
          <%!-- org header --%>
          <div style="padding:20px 20px 16px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));display:flex;align-items:flex-start;justify-content:space-between;gap:16px;">
            <div style="flex:1;min-width:0;">
              <p style={"font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#{BrandTheme.scheme(@display_org).primary};"}>
                {@display_org.name}
              </p>
              <p
                :if={@display_org.legal_name}
                style="font-size:12px;color:var(--s-muted,#9A9384);margin-top:2px;"
              >
                {@display_org.legal_name}
              </p>
              <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
                <span :if={@display_org.phone} style="font-size:12px;color:var(--s-dim,#6E675A);">
                  {@display_org.phone}
                </span>
                <span
                  :if={@display_org.phone && @display_org.website}
                  style="color:var(--s-dim,#6E675A);"
                >
                  ·
                </span>
                <span :if={@display_org.website} style="font-size:12px;color:var(--s-dim,#6E675A);">
                  {@display_org.website}
                </span>
                <span :if={@display_org.contact_email} style="color:var(--s-dim,#6E675A);">·</span>
                <span
                  :if={@display_org.contact_email}
                  style="font-size:12px;color:var(--s-dim,#6E675A);"
                >
                  {@display_org.contact_email}
                </span>
              </div>
            </div>
            <% logo_url =
              case @display_org.logo_colour_key do
                nil ->
                  nil

                key ->
                  case OpenSauce.Storage.url(key) do
                    {:ok, u} -> u
                    _ -> nil
                  end
              end %>
            <img
              :if={logo_url}
              src={logo_url}
              style="width:64px;height:64px;object-fit:contain;flex-shrink:0;"
              alt=""
            />
          </div>

          <%!-- invoice meta + bill to --%>
          <div style="padding:16px 20px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));display:flex;gap:20px;align-items:flex-start;">
            <%!-- left: invoice number + dates --%>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);">
                Invoice
              </p>
              <p style="font-family:monospace;font-size:18px;font-weight:700;color:var(--s-text,#F4EFE2);margin-top:2px;">
                #{format_invoice_number(@invoice.invoice_number)}
              </p>
              <div style="margin-top:10px;display:flex;flex-direction:column;gap:4px;">
                <div style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:var(--s-dim,#6E675A);width:44px;">Issued</span>
                  <span style="font-size:11px;color:var(--s-text,#F4EFE2);">
                    {format_date(@invoice.issued_on)}
                  </span>
                </div>
                <div :if={@invoice.due_on} style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:var(--s-dim,#6E675A);width:44px;">Due</span>
                  <span style="font-size:11px;color:var(--s-text,#F4EFE2);">
                    {format_date(@invoice.due_on)}
                  </span>
                </div>
              </div>
            </div>
            <%!-- right: bill to --%>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);">
                Bill To
              </p>
              <p style="font-size:14px;font-weight:600;color:var(--s-text,#F4EFE2);margin-top:4px;">
                {customer_name(@display_customer)}
              </p>
              <div
                :if={billing_address = @display_customer && billing_address_of(@display_customer)}
                style="margin-top:4px;"
              >
                <p :if={billing_address.street} style="font-size:12px;color:var(--s-muted,#9A9384);">
                  {billing_address.street}
                </p>
                <p style="font-size:12px;color:var(--s-muted,#9A9384);">
                  {[billing_address.city, billing_address.province, billing_address.zip]
                  |> Enum.reject(&is_nil/1)
                  |> Enum.join(", ")}
                </p>
              </div>
              <p
                :if={@display_customer && email_of(@display_customer)}
                style="font-size:12px;color:var(--s-dim,#6E675A);margin-top:4px;"
              >
                {email_of(@display_customer)}
              </p>
            </div>
          </div>

          <%!-- line items --%>
          <div style="padding:16px 20px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:10px;">
              <span style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);">
                Description
              </span>
              <span style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);">
                Amount
              </span>
            </div>
            <div style="display:flex;flex-direction:column;">
              <%!-- engagement groups --%>
              <div :for={group_items <- @item_groups}>
                <% eng = Enum.find(group_items, &(&1["type"] == "engagement")) %>
                <% jobs = Enum.filter(group_items, &(&1["type"] == "job")) %>
                <% group_customs = Enum.filter(group_items, &(&1["type"] == "custom")) %>
                <%!-- engagement fee row --%>
                <div
                  :if={eng}
                  style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:8px 0;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.4));"
                >
                  <p style="flex:1;font-size:13px;font-weight:700;color:var(--s-text,#F4EFE2);min-width:0;">
                    {eng["label"]}
                  </p>
                  <span
                    :if={eng["amount"] && eng["amount"] != "0.00"}
                    style="font-size:13px;font-weight:700;color:var(--s-text,#F4EFE2);white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                  >
                    {format_money(@display_org.currency, eng["amount"])}
                  </span>
                </div>
                <%!-- job rows --%>
                <div
                  :for={job <- jobs}
                  style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:7px 0 7px 12px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.3));"
                >
                  <div style="flex:1;min-width:0;">
                    <p style="font-size:12.5px;color:var(--s-muted,#9A9384);">{job["label"]}</p>
                    <p
                      :if={job["date"]}
                      style="font-size:11px;color:var(--s-dim,#6E675A);margin-top:2px;"
                    >
                      {job["date"]}
                    </p>
                  </div>
                  <span
                    :if={job["amount"] && job["amount"] != "0.00"}
                    style="font-size:12.5px;color:var(--s-muted,#9A9384);white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                  >
                    {format_money(@display_org.currency, job["amount"])}
                  </span>
                </div>
                <%!-- group custom line item rows --%>
                <div
                  :for={item <- group_customs}
                  style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:7px 0 7px 12px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.3));"
                >
                  <p style="flex:1;font-size:12.5px;color:var(--s-muted,#9A9384);min-width:0;">
                    {item["label"]}
                  </p>
                  <span
                    :if={item["amount"] && item["amount"] != "0.00"}
                    style="font-size:12.5px;color:var(--s-muted,#9A9384);white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                  >
                    {format_money(@display_org.currency, item["amount"])}
                  </span>
                </div>
              </div>
              <%!-- ungrouped / legacy flat items --%>
              <div
                :for={item <- @ungrouped_items}
                style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:8px 0;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.4));"
              >
                <div style="flex:1;min-width:0;">
                  <p style="font-size:13px;color:var(--s-text,#F4EFE2);">{item["label"]}</p>
                  <p
                    :if={item["date"]}
                    style="font-size:11px;color:var(--s-dim,#6E675A);margin-top:2px;"
                  >
                    {item["date"]}
                  </p>
                </div>
                <span
                  :if={item["amount"] && item["amount"] != "0.00"}
                  style="font-size:13px;color:var(--s-text,#F4EFE2);white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;"
                >
                  {format_money(@display_org.currency, item["amount"])}
                </span>
              </div>
              <div
                :if={@item_groups == [] && @ungrouped_items == []}
                style="padding:12px 0;text-align:center;"
              >
                <p style="font-size:13px;color:var(--s-dim,#6E675A);">No line items.</p>
              </div>
            </div>
          </div>

          <%!-- totals --%>
          <div style="padding:0 20px 20px;">
            <%!-- subtotal row (only shown when there are taxes) --%>
            <div
              :if={@tax_lines != [] && @display_org.tax_mode == :exclusive}
              style="display:flex;justify-content:space-between;padding:6px 0;"
            >
              <span style="font-size:12px;color:var(--s-muted,#9A9384);">Subtotal</span>
              <span style="font-size:12px;color:var(--s-muted,#9A9384);font-variant-numeric:tabular-nums;">
                {format_money(@display_org.currency, @invoice.amount)}
              </span>
            </div>

            <%!-- tax lines (exclusive mode only) --%>
            <div
              :for={tax <- @tax_lines}
              style="display:flex;justify-content:space-between;padding:6px 0;"
            >
              <span style="font-size:12px;color:var(--s-muted,#9A9384);">
                {tax.name} ({tax.rate |> D.normalize() |> D.to_string()}%)
                <span :if={tax.registration_number} style="color:var(--s-dim,#6E675A);font-size:11px;">
                  · {tax.registration_number}
                </span>
              </span>
              <span style="font-size:12px;color:var(--s-muted,#9A9384);font-variant-numeric:tabular-nums;">
                {format_money(@display_org.currency, tax.amount)}
              </span>
            </div>

            <%!-- total --%>
            <div style="display:flex;justify-content:space-between;align-items:baseline;padding-top:10px;margin-top:4px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));">
              <span style="font-size:14px;font-weight:700;color:var(--s-text,#F4EFE2);letter-spacing:0.02em;">
                Total
              </span>
              <span style={"font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;color:#{BrandTheme.scheme(@display_org).primary};letter-spacing:-0.02em;font-variant-numeric:tabular-nums;"}>
                {format_money(@display_org.currency, @grand_total)}
              </span>
            </div>

            <p
              :if={@display_org.tax_mode == :inclusive && @tax_lines != []}
              style="font-size:11px;color:var(--s-dim,#6E675A);margin-top:6px;text-align:right;"
            >
              Includes {Enum.map_join(@tax_lines, ", ", fn t ->
                "#{D.normalize(t.rate) |> D.to_string()}% #{t.name}"
              end)}
            </p>
          </div>

          <%!-- payment info --%>
          <div
            :if={@display_org.payment_info}
            style="padding:14px 20px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));"
          >
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);margin-bottom:6px;">
              Payment
            </p>
            <p style="font-size:12px;color:var(--s-muted,#9A9384);white-space:pre-line;">
              {@display_org.payment_info}
            </p>
          </div>

          <%!-- notes --%>
          <div
            :if={@invoice.notes}
            style="padding:14px 20px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));"
          >
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);margin-bottom:6px;">
              Notes
            </p>
            <p style="font-size:12px;color:var(--s-muted,#9A9384);white-space:pre-line;">
              {@invoice.notes}
            </p>
          </div>

          <%!-- invoice terms --%>
          <div
            :if={@display_org.invoice_terms}
            style="padding:14px 20px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));"
          >
            <p style="font-size:11px;color:var(--s-dim,#6E675A);white-space:pre-line;">
              {@display_org.invoice_terms}
            </p>
          </div>

          <%!-- footer --%>
          <div
            :if={@display_org.invoice_footer}
            style="padding:10px 20px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));text-align:center;"
          >
            <p style="font-size:11px;color:var(--s-dim,#6E675A);">{@display_org.invoice_footer}</p>
          </div>
        </div>
      </div>

      <%!-- sticky action buttons --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:var(--s-bg,#16140E);border-top:1px solid var(--s-border,rgba(52,48,37,0.58));padding:10px 16px;display:flex;flex-direction:column;gap:8px;">
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
  def handle_params(%{"id" => id} = params, _url, socket) do
    member = socket.assigns.current_member
    return_to = Map.get(params, "return_to", ~p"/manage/invoices")
    invoice = load_invoice(id, member)
    live_org = socket.assigns.organisation

    {display_org, display_customer, tax_lines, grand_total} =
      case invoice.snapshot do
        nil ->
          tax_rates = load_tax_rates(member)
          {tl, gt} = compute_taxes(invoice.amount, tax_rates, live_org.tax_mode)
          {live_org, invoice.customer, tl, gt}

        snap ->
          restore_from_snapshot(snap, live_org, invoice.customer)
      end

    {item_groups, ungrouped_items} = group_line_items(invoice.line_items)

    socket =
      socket
      |> assign(:invoice, invoice)
      |> assign(:return_to, return_to)
      |> assign(:display_org, display_org)
      |> assign(:display_customer, display_customer)
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
    invoice = socket.assigns.invoice
    org = socket.assigns.organisation

    invoice =
      if is_nil(invoice.snapshot) do
        tax_rates = load_tax_rates(member)
        {tax_lines, grand_total} = compute_taxes(invoice.amount, tax_rates, org.tax_mode)
        snap = build_snapshot(invoice, org, tax_lines, grand_total)

        {:ok, snapped} =
          CRM.update_invoice(invoice, %{snapshot: snap},
            actor: member,
            tenant: member.organisation_id
          )

        snapped
      else
        invoice
      end

    {:ok, _} = CRM.mark_invoice_paid(invoice, actor: member, tenant: member.organisation_id)
    invoice = load_invoice(invoice.id, member)

    customer =
      Ash.get!(CRM.Customer, invoice.customer_id, actor: member, tenant: member.organisation_id)

    Portal.send_invoice_receipt(
      customer,
      org,
      invoice,
      socket.assigns.tax_lines,
      socket.assigns.grand_total
    )

    {:noreply,
     socket
     |> assign(:invoice, invoice)
     |> put_flash(:info, "Marked paid — receipt sent to #{customer.email}.")}
  end

  @impl true
  def handle_event("send_to_client", _params, socket) do
    member = socket.assigns.current_member
    invoice = socket.assigns.invoice
    org = socket.assigns.organisation

    invoice =
      if invoice.status == :draft do
        {:ok, sent} =
          CRM.mark_invoice_sent(invoice, actor: member, tenant: member.organisation_id)

        sent
      else
        invoice
      end

    invoice = load_invoice(invoice.id, member)

    customer =
      Ash.get!(CRM.Customer, invoice.customer_id, actor: member, tenant: member.organisation_id)

    tax_rates = load_tax_rates(member)
    {tax_lines, grand_total} = compute_taxes(invoice.amount, tax_rates, org.tax_mode)

    snap = build_snapshot(invoice, org, tax_lines, grand_total)

    {:ok, invoice} =
      CRM.update_invoice(invoice, %{snapshot: snap},
        actor: member,
        tenant: member.organisation_id
      )

    Portal.send_invoice_to_client(customer, org, invoice, tax_lines, grand_total)

    {:noreply,
     socket
     |> assign(:invoice, invoice)
     |> assign(:display_org, org)
     |> assign(:display_customer, customer)
     |> assign(:tax_lines, tax_lines)
     |> assign(:grand_total, grand_total)
     |> put_flash(:info, "Invoice sent to #{customer.email}.")}
  end

  @impl true
  def handle_event("void_invoice", _params, socket) do
    member = socket.assigns.current_member

    {:ok, _} =
      CRM.void_invoice(socket.assigns.invoice, actor: member, tenant: member.organisation_id)

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
    [actor: member, tenant: member.organisation_id]
    |> Accounts.list_tax_rates!()
    |> Enum.sort_by(& &1.position)
  rescue
    _ -> []
  end

  defp build_snapshot(invoice, org, tax_lines, grand_total) do
    customer = invoice.customer
    addr = customer && customer.billing_address

    %{
      "org" => %{
        "name" => org.name,
        "legal_name" => org.legal_name,
        "phone" => org.phone,
        "website" => org.website,
        "contact_email" => org.contact_email,
        "payment_info" => org.payment_info,
        "invoice_terms" => org.invoice_terms,
        "invoice_footer" => org.invoice_footer,
        "logo_colour_key" => org.logo_colour_key,
        "currency" => to_string(org.currency),
        "tax_mode" => to_string(org.tax_mode)
      },
      "customer" => %{
        "first_name" => customer && customer.first_name,
        "last_name" => customer && customer.last_name,
        "email" => customer && customer.email,
        "billing_address" =>
          addr &&
            %{
              "street" => addr.street,
              "city" => addr.city,
              "province" => addr.province,
              "zip" => addr.zip
            }
      },
      "tax_lines" =>
        Enum.map(tax_lines, fn t ->
          %{
            "name" => t.name,
            "rate" => D.to_string(D.normalize(t.rate)),
            "registration_number" => t.registration_number,
            "amount" => D.to_string(t.amount)
          }
        end),
      "grand_total" => D.to_string(grand_total)
    }
  end

  defp restore_from_snapshot(snap, live_org, live_customer) do
    org_snap = snap["org"] || %{}
    cust_snap = snap["customer"] || %{}
    addr_snap = cust_snap["billing_address"]

    display_org = %{
      live_org
      | name: org_snap["name"] || live_org.name,
        legal_name: org_snap["legal_name"],
        phone: org_snap["phone"],
        website: org_snap["website"],
        contact_email: org_snap["contact_email"],
        payment_info: org_snap["payment_info"],
        invoice_terms: org_snap["invoice_terms"],
        invoice_footer: org_snap["invoice_footer"],
        logo_colour_key: org_snap["logo_colour_key"],
        currency: if(c = org_snap["currency"], do: String.to_atom(c), else: live_org.currency),
        tax_mode: if(m = org_snap["tax_mode"], do: String.to_atom(m), else: live_org.tax_mode)
    }

    display_customer =
      if cust_snap == %{} do
        live_customer
      else
        %{
          first_name: cust_snap["first_name"],
          last_name: cust_snap["last_name"],
          email: cust_snap["email"],
          billing_address:
            addr_snap &&
              %{
                street: addr_snap["street"],
                city: addr_snap["city"],
                province: addr_snap["province"],
                zip: addr_snap["zip"]
              }
        }
      end

    tax_lines =
      Enum.map(snap["tax_lines"] || [], fn l ->
        %{
          name: l["name"],
          rate: parse_decimal(l["rate"]),
          registration_number: l["registration_number"],
          amount: parse_decimal(l["amount"])
        }
      end)

    grand_total = parse_decimal(snap["grand_total"])

    {display_org, display_customer, tax_lines, grand_total}
  end

  defp compute_taxes(subtotal, tax_rates, :exclusive) do
    subtotal_d = parse_decimal(subtotal)

    {tax_lines, _running} =
      Enum.map_reduce(tax_rates, subtotal_d, fn rate, acc ->
        base = if rate.is_compound, do: acc, else: subtotal_d
        amount = base |> D.mult(D.div(rate.rate, D.new(100))) |> D.round(2)

        line = %{
          name: rate.name,
          rate: rate.rate,
          registration_number: rate.registration_number,
          amount: amount
        }

        {line, D.add(acc, amount)}
      end)

    tax_total = Enum.reduce(tax_lines, D.new(0), fn t, acc -> D.add(acc, t.amount) end)
    grand_total = subtotal_d |> D.add(tax_total) |> D.round(2)
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

  defp customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"
  defp customer_name(_), do: "Unknown customer"

  defp billing_address_of(%{billing_address: addr}), do: addr
  defp billing_address_of(_), do: nil

  defp email_of(%{email: email}), do: email
  defp email_of(_), do: nil

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

  defp status_badge_style(_), do: "background:rgba(154,147,132,0.15);color:var(--s-muted,#9A9384);"
end
