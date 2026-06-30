defmodule OpenSauceWeb.PortalLive.Invoice do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias Decimal, as: D
  alias OpenSauce.Accounts
  alias OpenSauce.CRM

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    org_id = socket.assigns.portal_org_id
    customer = socket.assigns.current_customer
    live_org = socket.assigns.organisation

    invoice =
      Ash.get!(CRM.Invoice, id,
        authorize?: false,
        tenant: org_id,
        load: [customer: [:billing_address]]
      )

    if invoice.customer_id != customer.id || invoice.status == :draft do
      raise Ash.Error.Query.NotFound, resource: CRM.Invoice
    end

    {display_org, display_customer, tax_lines, grand_total} =
      case invoice.snapshot do
        nil ->
          tax_rates =
            Accounts.list_tax_rates!(authorize?: false, tenant: org_id)
            |> Enum.sort_by(& &1.position)

          {tl, gt} = compute_taxes(invoice.amount, tax_rates, live_org.tax_mode)
          {live_org, invoice.customer, tl, gt}

        snap ->
          restore_from_snapshot(snap, live_org, invoice.customer)
      end

    {item_groups, ungrouped_items} = group_line_items(invoice.line_items)

    socket =
      socket
      |> assign(:invoice, invoice)
      |> assign(:display_org, display_org)
      |> assign(:display_customer, display_customer)
      |> assign(:tax_lines, tax_lines)
      |> assign(:grand_total, grand_total)
      |> assign(:item_groups, item_groups)
      |> assign(:ungrouped_items, ungrouped_items)
      |> assign(:page_title, "Invoice ##{pad(invoice.invoice_number)}")
      |> assign(:main_bg, "bg-[#16140E]")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:60px;">

      <%!-- minimal top bar --%>
      <div style="padding:16px 16px 10px;display:flex;align-items:center;justify-content:space-between;">
        <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;letter-spacing:-0.02em;color:#54B57E;">
          {@display_org.name}
        </p>
        <span :if={@invoice.status == :paid} style="background:rgba(84,181,126,0.15);color:#54B57E;border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;">
          Paid
        </span>
      </div>

      <%!-- document --%>
      <div style="padding:0 16px 16px;">
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:20px;overflow:hidden;">

          <%!-- org header --%>
          <div style="padding:20px 20px 16px;border-bottom:1px solid rgba(52,48,37,0.58);display:flex;align-items:flex-start;justify-content:space-between;gap:16px;">
            <div style="flex:1;min-width:0;">
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#54B57E;">
                {@display_org.name}
              </p>
              <p :if={@display_org.legal_name} style="font-size:12px;color:#9A9384;margin-top:2px;">{@display_org.legal_name}</p>
              <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
                <span :if={@display_org.phone} style="font-size:12px;color:#6E675A;">{@display_org.phone}</span>
                <span :if={@display_org.phone && @display_org.website} style="color:#6E675A;">·</span>
                <span :if={@display_org.website} style="font-size:12px;color:#6E675A;">{@display_org.website}</span>
                <span :if={@display_org.contact_email} style="color:#6E675A;">·</span>
                <span :if={@display_org.contact_email} style="font-size:12px;color:#6E675A;">{@display_org.contact_email}</span>
              </div>
            </div>
            <% logo_url = case @display_org.logo_colour_key do
              nil -> nil
              key -> case OpenSauce.Storage.url(key) do {:ok, u} -> u; _ -> nil end
            end %>
            <img :if={logo_url} src={logo_url} style="width:64px;height:64px;object-fit:contain;flex-shrink:0;" alt="" />
          </div>

          <%!-- invoice meta + bill to --%>
          <div style="padding:16px 20px;border-bottom:1px solid rgba(52,48,37,0.58);display:flex;gap:20px;align-items:flex-start;">
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Invoice</p>
              <p style="font-family:monospace;font-size:18px;font-weight:700;color:#F4EFE2;margin-top:2px;">#{pad(@invoice.invoice_number)}</p>
              <div style="margin-top:10px;display:flex;flex-direction:column;gap:4px;">
                <div style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:#6E675A;width:44px;">Issued</span>
                  <span style="font-size:11px;color:#F4EFE2;">{fmt_date(@invoice.issued_on)}</span>
                </div>
                <div :if={@invoice.due_on} style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:#6E675A;width:44px;">Due</span>
                  <span style="font-size:11px;color:#F4EFE2;">{fmt_date(@invoice.due_on)}</span>
                </div>
              </div>
            </div>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Bill To</p>
              <p style="font-size:14px;font-weight:600;color:#F4EFE2;margin-top:4px;">{customer_name(@display_customer)}</p>
              <div :if={addr = @display_customer && billing_address_of(@display_customer)} style="margin-top:4px;">
                <p :if={addr.street} style="font-size:12px;color:#9A9384;">{addr.street}</p>
                <p style="font-size:12px;color:#9A9384;">
                  {[addr.city, addr.province, addr.zip] |> Enum.reject(&is_nil/1) |> Enum.join(", ")}
                </p>
              </div>
              <p :if={@display_customer && email_of(@display_customer)} style="font-size:12px;color:#6E675A;margin-top:4px;">
                {email_of(@display_customer)}
              </p>
            </div>
          </div>

          <%!-- line items --%>
          <div style="padding:16px 20px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:10px;">
              <span style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Description</span>
              <span style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Amount</span>
            </div>
            <div :for={group <- @item_groups}>
              <% eng = Enum.find(group, &(&1["type"] == "engagement")) %>
              <% jobs = Enum.filter(group, &(&1["type"] == "job")) %>
              <div :if={eng} style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:8px 0;border-bottom:1px solid rgba(52,48,37,0.4);">
                <p style="flex:1;font-size:13px;font-weight:700;color:#F4EFE2;min-width:0;">{eng["label"]}</p>
                <span :if={eng["amount"] && eng["amount"] != "0.00"} style="font-size:13px;font-weight:700;color:#F4EFE2;white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;">
                  {fmt_money(@display_org.currency, eng["amount"])}
                </span>
              </div>
              <div :for={job <- jobs} style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:7px 0 7px 12px;border-bottom:1px solid rgba(52,48,37,0.3);">
                <div style="flex:1;min-width:0;">
                  <p style="font-size:12.5px;color:#9A9384;">{job["label"]}</p>
                  <p :if={job["date"]} style="font-size:11px;color:#6E675A;margin-top:2px;">{job["date"]}</p>
                </div>
                <span :if={job["amount"] && job["amount"] != "0.00"} style="font-size:12.5px;color:#9A9384;white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;">
                  {fmt_money(@display_org.currency, job["amount"])}
                </span>
              </div>
            </div>
            <div :for={item <- @ungrouped_items} style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:8px 0;border-bottom:1px solid rgba(52,48,37,0.4);">
              <div style="flex:1;min-width:0;">
                <p style="font-size:13px;color:#F4EFE2;">{item["label"]}</p>
                <p :if={item["date"]} style="font-size:11px;color:#6E675A;margin-top:2px;">{item["date"]}</p>
              </div>
              <span :if={item["amount"] && item["amount"] != "0.00"} style="font-size:13px;color:#F4EFE2;white-space:nowrap;font-variant-numeric:tabular-nums;flex-shrink:0;">
                {fmt_money(@display_org.currency, item["amount"])}
              </span>
            </div>
            <div :if={@item_groups == [] && @ungrouped_items == []} style="padding:12px 0;text-align:center;">
              <p style="font-size:13px;color:#6E675A;">No line items.</p>
            </div>
          </div>

          <%!-- totals --%>
          <div style="padding:0 20px 20px;">
            <div :if={@tax_lines != [] && @display_org.tax_mode == :exclusive} style="display:flex;justify-content:space-between;padding:6px 0;">
              <span style="font-size:12px;color:#9A9384;">Subtotal</span>
              <span style="font-size:12px;color:#9A9384;font-variant-numeric:tabular-nums;">{fmt_money(@display_org.currency, @invoice.amount)}</span>
            </div>
            <div :for={tax <- @tax_lines} style="display:flex;justify-content:space-between;padding:6px 0;">
              <span style="font-size:12px;color:#9A9384;">
                {tax.name} ({tax.rate |> D.normalize() |> D.to_string()}%)
                <span :if={tax.registration_number} style="color:#6E675A;font-size:11px;">· {tax.registration_number}</span>
              </span>
              <span style="font-size:12px;color:#9A9384;font-variant-numeric:tabular-nums;">{fmt_money(@display_org.currency, tax.amount)}</span>
            </div>
            <div style="display:flex;justify-content:space-between;align-items:baseline;padding-top:10px;margin-top:4px;border-top:1px solid rgba(52,48,37,0.58);">
              <span style="font-size:14px;font-weight:700;color:#F4EFE2;">Total</span>
              <span style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;color:#54B57E;letter-spacing:-0.02em;font-variant-numeric:tabular-nums;">
                {fmt_money(@display_org.currency, @grand_total)}
              </span>
            </div>
            <p :if={@display_org.tax_mode == :inclusive && @tax_lines != []} style="font-size:11px;color:#6E675A;margin-top:6px;text-align:right;">
              Includes {Enum.map_join(@tax_lines, ", ", fn t -> "#{D.normalize(t.rate) |> D.to_string()}% #{t.name}" end)}
            </p>
          </div>

          <%!-- payment info --%>
          <div :if={@display_org.payment_info} style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">Payment</p>
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@display_org.payment_info}</p>
          </div>

          <%!-- notes --%>
          <div :if={@invoice.notes} style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">Notes</p>
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@invoice.notes}</p>
          </div>

          <div :if={@display_org.invoice_terms} style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:11px;color:#6E675A;white-space:pre-line;">{@display_org.invoice_terms}</p>
          </div>

          <div :if={@display_org.invoice_footer} style="padding:10px 20px;border-top:1px solid rgba(52,48,37,0.58);text-align:center;">
            <p style="font-size:11px;color:#6E675A;">{@display_org.invoice_footer}</p>
          </div>
        </div>
      </div>
    </div>
    """
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

    {display_org, display_customer, tax_lines, parse_decimal(snap["grand_total"])}
  end

  defp compute_taxes(subtotal, tax_rates, :exclusive) do
    subtotal_d = parse_decimal(subtotal)

    {tax_lines, _running} =
      Enum.map_reduce(tax_rates, subtotal_d, fn rate, acc ->
        base = if rate.is_compound, do: acc, else: subtotal_d
        amount = D.mult(base, D.div(rate.rate, D.new(100))) |> D.round(2)
        {%{name: rate.name, rate: rate.rate, registration_number: rate.registration_number, amount: amount}, D.add(acc, amount)}
      end)

    tax_total = Enum.reduce(tax_lines, D.new(0), &D.add(&2, &1.amount))
    {tax_lines, D.add(subtotal_d, tax_total) |> D.round(2)}
  end

  defp compute_taxes(subtotal, _rates, _inclusive), do: {[], parse_decimal(subtotal)}

  defp group_line_items(items) do
    {groups_map, group_order, ungrouped} =
      Enum.reduce(items, {%{}, [], []}, fn item, {map, order, flat} ->
        case item["group_id"] do
          nil -> {map, order, flat ++ [item]}
          gid ->
            {Map.update(map, gid, [item], &(&1 ++ [item])),
             if(gid in order, do: order, else: order ++ [gid]), flat}
        end
      end)

    {Enum.map(group_order, &Map.get(groups_map, &1, [])), ungrouped}
  end

  defp parse_decimal(nil), do: D.new(0)
  defp parse_decimal(%D{} = d), do: d
  defp parse_decimal(s) when is_binary(s) do
    case D.parse(s) do
      {d, ""} -> d
      _ -> D.new(0)
    end
  end

  defp fmt_money(currency, amount) do
    OpenSauceWeb.HtmlHelpers.format_currency(currency, amount)
  end

  defp fmt_date(nil), do: "—"
  defp fmt_date(%Date{} = d), do: Calendar.strftime(d, "%d %b %Y")

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 4, "0")

  defp customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"
  defp customer_name(_), do: ""

  defp billing_address_of(%{billing_address: addr}), do: addr
  defp billing_address_of(_), do: nil

  defp email_of(%{email: email}), do: email
  defp email_of(_), do: nil

end
