defmodule OpenSauce.Portal do
  @moduledoc false

  import Swoosh.Email

  alias Decimal, as: D
  alias OpenSauce.BrandTheme

  @resource_salt "portal-resource"
  @access_salt "portal-access"
  @resource_ttl 60 * 60 * 24 * 30
  @access_ttl 60 * 60 * 48

  def sign_resource_token(org_id, customer_id, type, resource_id) do
    Phoenix.Token.sign(
      OpenSauceWeb.Endpoint,
      @resource_salt,
      %{org_id: org_id, customer_id: customer_id, type: type, id: resource_id}
    )
  end

  def verify_resource_token(token) do
    Phoenix.Token.verify(OpenSauceWeb.Endpoint, @resource_salt, token, max_age: @resource_ttl)
  end

  def sign_access_token(org_id, customer_id, type, resource_id) do
    Phoenix.Token.sign(
      OpenSauceWeb.Endpoint,
      @access_salt,
      %{org_id: org_id, customer_id: customer_id, type: type, id: resource_id}
    )
  end

  def verify_access_token(token) do
    Phoenix.Token.verify(OpenSauceWeb.Endpoint, @access_salt, token, max_age: @access_ttl)
  end

  # Sends the "you have an invoice" email — includes the portal link AND an inline
  # copy of the invoice so the client has it for their records without clicking anything.
  def send_invoice_to_client(customer, org, invoice, tax_lines, grand_total) do
    token = sign_resource_token(org.id, customer.id, "invoice", invoice.id)
    url = OpenSauceWeb.Endpoint.url() <> "/c/view/#{token}"
    {from_name, from_addr} = sender(org)
    name = customer_name(customer)
    num = pad(invoice.invoice_number)

    console_log("INVOICE LINK (→ triggers access email)", url)

    new()
    |> from({from_name, from_addr})
    |> to({name, customer.email})
    |> subject("Invoice ##{num} from #{org.name}")
    |> html_body(invoice_email_body(name, org, invoice, tax_lines, grand_total, url))
    |> OpenSauce.Mailer.deliver!()
  end

  # Sends a "paid — thank you" receipt with the invoice copy.
  def send_invoice_receipt(customer, org, invoice, tax_lines, grand_total) do
    {from_name, from_addr} = sender(org)
    name = customer_name(customer)
    num = pad(invoice.invoice_number)

    new()
    |> from({from_name, from_addr})
    |> to({name, customer.email})
    |> subject("Receipt — Invoice ##{num} from #{org.name}")
    |> html_body(receipt_email_body(name, org, invoice, tax_lines, grand_total))
    |> OpenSauce.Mailer.deliver!()
  end

  # Sends the "view this estimate" resource link email.
  def send_resource_link(customer, org, type, resource_id) do
    token = sign_resource_token(org.id, customer.id, type, resource_id)
    url = OpenSauceWeb.Endpoint.url() <> "/c/view/#{token}"
    lbl = label(type)
    {from_name, from_addr} = sender(org)

    console_log("#{String.upcase(lbl)} LINK (→ triggers access email)", url)

    new()
    |> from({from_name, from_addr})
    |> to({customer_name(customer), customer.email})
    |> subject("Your #{lbl} from #{org.name}")
    |> html_body(resource_body(customer_name(customer), org, lbl, url))
    |> OpenSauce.Mailer.deliver!()
  end

  # Called by PortalController.view/2 — fires the short-lived access link.
  def send_access_link(customer, org, type, resource_id) do
    token = sign_access_token(org.id, customer.id, type, resource_id)
    url = OpenSauceWeb.Endpoint.url() <> "/c/access/#{token}"
    lbl = label(type)
    {from_name, from_addr} = sender(org)

    console_log("ACCESS LINK (click to open portal)", url)

    new()
    |> from({from_name, from_addr})
    |> to({customer_name(customer), customer.email})
    |> subject("Your access link — #{org.name}")
    |> html_body(access_body(customer_name(customer), org, lbl, url))
    |> OpenSauce.Mailer.deliver!()
  end

  # --

  def customer_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  def customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"

  defp label("invoice"), do: "invoice"
  defp label("estimate"), do: "estimate"

  defp sender(%{email_from_name: n, email_from_address: a}) when is_binary(n) and is_binary(a), do: {n, a}

  defp sender(%{name: n}), do: {n, Application.get_env(:opensauce, :email_from_address, "noreply@opensauce.app")}

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 4, "0")

  defp console_log(label, url) do
    IO.puts("""

    -- #{label} #{String.duplicate("-", max(0, 60 - String.length(label)))}
       #{url}
    #{String.duplicate("-", 65)}
    """)
  end

  # -- Email bodies --

  defp invoice_email_body(name, org, invoice, tax_lines, grand_total, url) do
    num = pad(invoice.invoice_number)
    accent = BrandTheme.light_primary(org)
    on_accent = BrandTheme.light_on_primary(org)
    issued = format_date(invoice.issued_on)

    due =
      if invoice.due_on,
        do: "<p style='margin:2px 0;font-size:13px;color:#555;'>Due: #{format_date(invoice.due_on)}</p>",
        else: ""

    line_items_html =
      Enum.map_join(invoice.line_items || [], fn item ->
        amount =
          if item["amount"] && item["amount"] != "0.00",
            do: format_currency(org.currency, item["amount"]),
            else: ""

        indent =
          if item["type"] == "job", do: "padding-left:16px;color:#777;", else: "font-weight:600;"

        """
        <tr>
          <td style="padding:6px 0;font-size:13px;border-bottom:1px solid #eee;#{indent}">#{item["label"]}</td>
          <td style="padding:6px 0;font-size:13px;border-bottom:1px solid #eee;text-align:right;white-space:nowrap;">#{amount}</td>
        </tr>
        """
      end)

    tax_rows =
      Enum.map_join(tax_lines, fn t ->
        """
        <tr>
          <td style="padding:4px 0;font-size:12px;color:#777;">#{t.name} (#{t.rate |> D.normalize() |> D.to_string()}%)</td>
          <td style="padding:4px 0;font-size:12px;color:#777;text-align:right;">#{format_currency(org.currency, t.amount)}</td>
        </tr>
        """
      end)

    subtotal_row =
      if tax_lines == [] do
        ""
      else
        """
        <tr>
          <td style="padding:4px 0;font-size:12px;color:#777;">Subtotal</td>
          <td style="padding:4px 0;font-size:12px;color:#777;text-align:right;">#{format_currency(org.currency, invoice.amount)}</td>
        </tr>
        """
      end

    """
    <html><body style="font-family:system-ui,sans-serif;color:#1a1a1a;max-width:560px;margin:32px auto;padding:0 24px;">
      <p style="font-size:22px;font-weight:700;color:#{accent};margin-bottom:4px;">#{org.name}</p>
      #{if org.legal_name, do: "<p style='font-size:12px;color:#999;margin:0 0 16px;'>#{org.legal_name}</p>", else: ""}

      <table width="100%" style="border-collapse:collapse;margin-bottom:24px;">
        <tr>
          <td>
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#999;margin:0 0 4px;">Invoice</p>
            <p style="font-family:monospace;font-size:20px;font-weight:700;margin:0 0 4px;">##{num}</p>
            <p style="margin:2px 0;font-size:13px;color:#555;">Issued: #{issued}</p>
            #{due}
          </td>
          <td style="text-align:right;vertical-align:top;">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#999;margin:0 0 4px;">Billed To</p>
            <p style="font-size:14px;font-weight:600;margin:0;">#{name}</p>
          </td>
        </tr>
      </table>

      <table width="100%" style="border-collapse:collapse;margin-bottom:24px;">
        <thead>
          <tr>
            <th style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#999;text-align:left;padding-bottom:6px;border-bottom:2px solid #eee;">Description</th>
            <th style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#999;text-align:right;padding-bottom:6px;border-bottom:2px solid #eee;">Amount</th>
          </tr>
        </thead>
        <tbody>#{line_items_html}</tbody>
        <tfoot>
          #{subtotal_row}
          #{tax_rows}
          <tr>
            <td style="padding-top:10px;font-size:15px;font-weight:700;border-top:2px solid #eee;">Total</td>
            <td style="padding-top:10px;font-size:20px;font-weight:700;color:#{accent};text-align:right;border-top:2px solid #eee;">#{format_currency(org.currency, grand_total)}</td>
          </tr>
        </tfoot>
      </table>

      #{if org.payment_info, do: "<p style='font-size:12px;color:#555;white-space:pre-line;border-top:1px solid #eee;padding-top:16px;'><strong>Payment:</strong><br>#{org.payment_info}</p>", else: ""}

      <p style="margin:28px 0 8px;">
        <a href="#{url}" style="background:#{accent};color:#{on_accent};padding:13px 26px;border-radius:8px;text-decoration:none;font-weight:700;display:inline-block;">
          View invoice online
        </a>
      </p>
      <p style="color:#999;font-size:12px;">The link above will send an access link to this email address.</p>
    </body></html>
    """
  end

  defp receipt_email_body(name, org, invoice, tax_lines, grand_total) do
    num = pad(invoice.invoice_number)
    accent = BrandTheme.light_primary(org)
    paid_on = format_date(Date.utc_today())

    """
    <html><body style="font-family:system-ui,sans-serif;color:#1a1a1a;max-width:560px;margin:32px auto;padding:0 24px;">
      <p style="font-size:22px;font-weight:700;color:#{accent};margin-bottom:4px;">#{org.name}</p>
      <p style="font-size:15px;font-weight:700;color:#{accent};margin:0 0 24px;">✓ Payment received</p>

      <p style="font-size:13px;color:#555;">Hi #{name},</p>
      <p style="font-size:13px;color:#555;">Thank you — we've received your payment for Invoice ##{num}. This email is your receipt.</p>

      <table width="100%" style="border-collapse:collapse;margin:24px 0;">
        <tr>
          <td style="font-size:13px;color:#777;padding:4px 0;">Invoice</td>
          <td style="font-size:13px;font-weight:600;text-align:right;">##{num}</td>
        </tr>
        <tr>
          <td style="font-size:13px;color:#777;padding:4px 0;">Paid on</td>
          <td style="font-size:13px;font-weight:600;text-align:right;">#{paid_on}</td>
        </tr>
        <tr>
          <td style="font-size:15px;font-weight:700;padding-top:10px;border-top:2px solid #eee;">Total paid</td>
          <td style="font-size:20px;font-weight:700;color:#{accent};text-align:right;padding-top:10px;border-top:2px solid #eee;">#{format_currency(org.currency, grand_total)}</td>
        </tr>
      </table>

      #{if tax_lines == [], do: "", else: "<p style='font-size:11px;color:#999;'>Includes #{Enum.map_join(tax_lines, ", ", fn t -> "#{t.rate |> D.normalize() |> D.to_string()}% #{t.name}" end)}</p>"}
    </body></html>
    """
  end

  defp resource_body(name, org, lbl, url) do
    article = if lbl == "estimate", do: "an", else: "a"

    """
    <html><body style="font-family:system-ui,sans-serif;color:#1a1a1a;max-width:480px;margin:32px auto;padding:0 24px;">
      <p>Hi #{name},</p>
      <p>#{org.name} has sent you #{article} #{lbl}.</p>
      <p style="margin:28px 0;">
        <a href="#{url}" style="background:#{BrandTheme.light_primary(org)};color:#{BrandTheme.light_on_primary(org)};padding:13px 26px;border-radius:8px;text-decoration:none;font-weight:700;display:inline-block;">
          View #{lbl}
        </a>
      </p>
      <p style="color:#999;font-size:12px;">This link is valid for 30 days and will send a short-lived access link to your email.</p>
    </body></html>
    """
  end

  defp access_body(name, org, lbl, url) do
    """
    <html><body style="font-family:system-ui,sans-serif;color:#1a1a1a;max-width:480px;margin:32px auto;padding:0 24px;">
      <p>Hi #{name},</p>
      <p>Click below to view your #{lbl} from #{org.name}. This link expires in 48 hours.</p>
      <p style="margin:28px 0;">
        <a href="#{url}" style="background:#{BrandTheme.light_primary(org)};color:#{BrandTheme.light_on_primary(org)};padding:13px 26px;border-radius:8px;text-decoration:none;font-weight:700;display:inline-block;">
          Open #{lbl}
        </a>
      </p>
      <p style="color:#999;font-size:12px;">If you didn't request this, you can ignore this email.</p>
    </body></html>
    """
  end

  defp format_date(nil), do: "—"
  defp format_date(%Date{} = d), do: Calendar.strftime(d, "%d %b %Y")

  defp format_currency(currency, amount) do
    OpenSauceWeb.HtmlHelpers.format_currency(currency, amount)
  end
end
