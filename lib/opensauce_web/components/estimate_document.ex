defmodule OpenSauceWeb.EstimateDocument do
  @moduledoc false
  use OpenSauceWeb, :html

  alias OpenSauce.BrandTheme
  alias OpenSauceWeb.HtmlHelpers

  @doc """
  Renders the estimate document card — org header, prepared-for, pricing,
  scope, paintings, signature, notes. Rendered in the org's chosen brand
  theme (light or dark) via the `--s-*` CSS vars, independent of the
  surrounding page chrome.

  Assigns:
    - `engagement`   — Engagement with :garden, :images loaded
    - `organisation` — Organisation
    - `customer`     — the customer to show in "Prepared For" (may be nil)
    - `paintings`    — list of `:painting` EngagementImages
  """
  attr :engagement, :map, required: true
  attr :organisation, :map, required: true
  attr :customer, :map, default: nil
  attr :paintings, :list, required: true

  attr :signable, :boolean,
    default: false,
    doc: "true when rendered in the client's own signing flow — adds the consent sentence to the paintings note"

  def estimate_document(assigns) do
    assigns = assign(assigns, :brand, BrandTheme.scheme(assigns.organisation))

    ~H"""
    <div style="padding:0 16px 16px;">
      <div style={"background:#{@brand.paper};border:1px solid #{BrandTheme.rgba(@brand.border, 0.58)};border-radius:20px;overflow:hidden;color:#{@brand.text};--s-bg:#{@brand.bg};--s-paper:#{@brand.paper};--s-border:#{BrandTheme.rgba(@brand.border, 0.58)};--s-text:#{@brand.text};--s-muted:#{@brand.muted};--s-dim:#{@brand.dim};"}>
        <%!-- org header --%>
        <div style="padding:20px 20px 16px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));display:flex;align-items:flex-start;justify-content:space-between;gap:16px;">
          <div style="flex:1;min-width:0;">
            <p style={"font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#{@brand.primary};"}>
              {@organisation.name}
            </p>
            <p
              :if={@organisation.legal_name}
              style="font-size:12px;color:var(--s-muted,#9A9384);margin-top:2px;"
            >
              {@organisation.legal_name}
            </p>
            <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
              <span :if={@organisation.phone} style="font-size:12px;color:var(--s-dim,#6E675A);">
                {@organisation.phone}
              </span>
              <span
                :if={@organisation.phone && @organisation.website}
                style="color:var(--s-dim,#6E675A);"
              >
                ·
              </span>
              <span :if={@organisation.website} style="font-size:12px;color:var(--s-dim,#6E675A);">
                {@organisation.website}
              </span>
              <span :if={@organisation.contact_email} style="color:var(--s-dim,#6E675A);">·</span>
              <span
                :if={@organisation.contact_email}
                style="font-size:12px;color:var(--s-dim,#6E675A);"
              >
                {@organisation.contact_email}
              </span>
            </div>
          </div>
          <% logo_url = logo_url(@organisation) %>
          <img
            :if={logo_url}
            src={logo_url}
            style="width:64px;height:64px;object-fit:contain;flex-shrink:0;"
            alt=""
          />
        </div>

        <%!-- estimate label + prepared for --%>
        <div style="padding:16px 20px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));display:flex;gap:20px;align-items:flex-start;">
          <div style="flex:1;min-width:0;">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);">
              Estimate
            </p>
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:18px;font-weight:700;color:var(--s-text,#F4EFE2);margin-top:2px;letter-spacing:-0.02em;">
              {@engagement.scope_title || "Garden estimate"}
            </p>
            <div
              :if={@engagement.term_start || @engagement.term_end}
              style="margin-top:10px;display:flex;flex-direction:column;gap:4px;"
            >
              <div :if={@engagement.term_start} style="display:flex;gap:8px;">
                <span style="font-size:11px;color:var(--s-dim,#6E675A);width:44px;">Start</span>
                <span style="font-size:11px;color:var(--s-text,#F4EFE2);">
                  {HtmlHelpers.format_date(@engagement.term_start)}
                </span>
              </div>
              <div :if={@engagement.term_end} style="display:flex;gap:8px;">
                <span style="font-size:11px;color:var(--s-dim,#6E675A);width:44px;">End</span>
                <span style="font-size:11px;color:var(--s-text,#F4EFE2);">
                  {HtmlHelpers.format_date(@engagement.term_end)}
                </span>
              </div>
            </div>
          </div>
          <div style="flex:1;min-width:0;">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);">
              Prepared For
            </p>
            <p style="font-size:14px;font-weight:600;color:var(--s-text,#F4EFE2);margin-top:4px;">
              {customer_name(@customer)}
            </p>
            <p
              :if={@engagement.garden}
              style="font-size:12px;color:var(--s-muted,#9A9384);margin-top:2px;"
            >
              {@engagement.garden.name}
            </p>
            <p
              :if={@customer && @customer.email}
              style="font-size:12px;color:var(--s-dim,#6E675A);margin-top:4px;"
            >
              {@customer.email}
            </p>
          </div>
        </div>

        <%!-- pricing --%>
        <div
          :if={@engagement.install_price || @engagement.maintenance_price_annual}
          style="padding:16px 20px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));"
        >
          <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);margin-bottom:8px;">
            Pricing
          </p>
          <div style="display:flex;flex-direction:column;gap:8px;">
            <div
              :if={@engagement.install_price}
              style="display:flex;align-items:baseline;justify-content:space-between;"
            >
              <span style="font-size:13px;color:var(--s-muted,#9A9384);">Installation</span>
              <span style="font-size:15px;font-weight:700;color:var(--s-text,#F4EFE2);">
                {HtmlHelpers.format_currency(@organisation.currency, @engagement.install_price)}
              </span>
            </div>
            <div
              :if={@engagement.maintenance_price_annual}
              style="display:flex;align-items:baseline;justify-content:space-between;"
            >
              <span style="font-size:13px;color:var(--s-muted,#9A9384);">
                Maintenance <span style="color:var(--s-dim,#6E675A);">/ year</span>
              </span>
              <span style="font-size:15px;font-weight:700;color:var(--s-text,#F4EFE2);">
                {HtmlHelpers.format_currency(
                  @organisation.currency,
                  @engagement.maintenance_price_annual
                )}
              </span>
            </div>
          </div>
        </div>

        <%!-- scope --%>
        <div style="padding:16px 20px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));">
          <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);margin-bottom:8px;">
            Scope
          </p>
          <p style="font-size:13px;color:var(--s-text,#F4EFE2);line-height:1.6;font-style:italic;">
            {scope_statement(@engagement, @paintings != [])}
          </p>
          <p
            :if={@engagement.scope_description}
            style="font-size:13px;color:var(--s-muted,#9A9384);line-height:1.6;margin-top:8px;"
          >
            {@engagement.scope_description}
          </p>
        </div>

        <%!-- paintings — contract scope images --%>
        <div
          :if={@paintings != []}
          style="border-bottom:1px solid var(--s-border,rgba(52,48,37,0.58));"
        >
          <div style={"padding:12px 20px 10px;background:#{BrandTheme.rgba(@brand.primary, 0.05)};border-bottom:1px solid #{BrandTheme.rgba(@brand.primary, 0.15)};"}>
            <p style={"font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#{@brand.primary};"}>
              Garden as digitally rendered
            </p>
            <p style="font-size:11px;color:var(--s-muted,#9A9384);margin-top:3px;line-height:1.4;">
              {paintings_note(@signable)}
            </p>
          </div>
          <div :for={painting <- @paintings}>
            <img
              src={HtmlHelpers.storage_url(painting.storage_key)}
              style="display:block;width:100%;height:auto;"
            />
          </div>
        </div>

        <%!-- signature block --%>
        <div style="padding:14px 20px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));">
          <div :if={@engagement.signature} style="display:flex;align-items:center;gap:10px;">
            <div style={"width:20px;height:20px;border-radius:50%;border:1.5px solid #{@brand.primary};display:flex;align-items:center;justify-content:center;flex-shrink:0;"}>
              <span style={"color:#{@brand.primary};font-size:12px;line-height:1;"}>✓</span>
            </div>
            <div>
              <p style={"font-size:12px;font-weight:600;color:#{@brand.primary};"}>
                Signed by {@engagement.signature.signed_by_name}
              </p>
              <p
                :if={@engagement.signature.signed_at}
                style="font-size:11px;color:var(--s-dim,#6E675A);"
              >
                {HtmlHelpers.format_date(@engagement.signature.signed_at)}
              </p>
            </div>
          </div>
          <div
            :if={is_nil(@engagement.signature)}
            style="border:1px dashed var(--s-border,rgba(52,48,37,0.58));border-radius:10px;padding:14px;text-align:center;"
          >
            <p style="font-size:12px;color:var(--s-dim,#6E675A);">Awaiting signature</p>
          </div>
        </div>

        <%!-- notes --%>
        <div
          :if={@engagement.notes}
          style="padding:14px 20px;border-top:1px solid var(--s-border,rgba(52,48,37,0.58));"
        >
          <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--s-dim,#6E675A);margin-bottom:6px;">
            Notes
          </p>
          <p style="font-size:12px;color:var(--s-muted,#9A9384);white-space:pre-line;">
            {@engagement.notes}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp paintings_note(true) do
    "The images below show the exact scope of this engagement. By signing, you confirm these renderings reflect the agreed design."
  end

  defp paintings_note(false), do: "The images below show the exact scope of this engagement."

  defp logo_url(%{logo_colour_key: nil}), do: nil

  defp logo_url(%{logo_colour_key: key}) do
    case OpenSauce.Storage.url(key) do
      {:ok, u} -> u
      _ -> nil
    end
  end

  defp scope_statement(%{status: status}, has_painting) do
    drawn_or_described = if has_painting, do: "as digitally rendered", else: "as described"

    case status do
      :in_progress -> "Garden #{drawn_or_described}, installed and maintained."
      :completed -> "Garden #{drawn_or_described}, installed and maintained."
      _ -> "Garden #{drawn_or_described}, proposed for installation and maintenance."
    end
  end

  defp customer_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  defp customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"
  defp customer_name(_), do: "Client"
end
