defmodule OpenSauceWeb.PortalLive.Estimate do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :signing, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    org_id = socket.assigns.portal_org_id
    customer = socket.assigns.current_customer

    engagement =
      Ash.get!(CRM.Engagement, id,
        authorize?: false,
        tenant: org_id,
        load: [:customer, :garden, :images]
      )

    if engagement.customer_id != customer.id do
      raise Ash.Error.Query.NotFound, resource: CRM.Engagement
    end

    paintings = Enum.filter(engagement.images, &(&1.type == :painting))

    {:noreply,
     socket
     |> assign(:engagement, engagement)
     |> assign(:paintings, paintings)
     |> assign(:page_title, engagement.scope_title || "Estimate")
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_event("start_sign", _params, socket) do
    {:noreply, assign(socket, :signing, true)}
  end

  def handle_event("cancel_sign", _params, socket) do
    {:noreply, assign(socket, :signing, false)}
  end

  def handle_event("confirm_sign", _params, socket) do
    engagement = socket.assigns.engagement
    customer = socket.assigns.current_customer
    org_id = socket.assigns.portal_org_id
    consent = consent_text(engagement, socket.assigns.organisation)

    signature = %{
      signed_by_name: OpenSauce.Portal.customer_name(customer),
      signed_by_email: customer.email,
      signed_at: DateTime.utc_now(),
      signed_from_ip: "portal",
      user_agent: "portal",
      engagement_snapshot: %{
        scope_title: engagement.scope_title,
        scope_description: engagement.scope_description,
        install_price: engagement.install_price && Decimal.to_string(engagement.install_price),
        maintenance_price_annual: engagement.maintenance_price_annual && Decimal.to_string(engagement.maintenance_price_annual)
      },
      consent_text: consent
    }

    {:ok, signed} =
      engagement
      |> Ash.Changeset.for_update(:sign, %{signature: signature}, authorize?: false, tenant: org_id)
      |> Ash.update()

    {:noreply,
     socket
     |> assign(:engagement, signed)
     |> assign(:signing, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:120px;">

      <%!-- minimal top bar --%>
      <div style="padding:16px 16px 10px;display:flex;align-items:center;justify-content:space-between;">
        <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;letter-spacing:-0.02em;color:#54B57E;">
          {@organisation.name}
        </p>
        <span style={"#{status_style(@engagement.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
          {Phoenix.Naming.humanize(@engagement.status)}
        </span>
      </div>

      <%!-- document --%>
      <div style="padding:0 16px 16px;">
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:20px;overflow:hidden;">

          <%!-- org header --%>
          <div style="padding:20px 20px 16px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#54B57E;">
              {@organisation.name}
            </p>
            <p :if={@organisation.legal_name} style="font-size:12px;color:#9A9384;margin-top:2px;">{@organisation.legal_name}</p>
            <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
              <span :if={@organisation.phone} style="font-size:12px;color:#6E675A;">{@organisation.phone}</span>
              <span :if={@organisation.phone && @organisation.website} style="color:#6E675A;">·</span>
              <span :if={@organisation.website} style="font-size:12px;color:#6E675A;">{@organisation.website}</span>
              <span :if={@organisation.contact_email} style="color:#6E675A;">·</span>
              <span :if={@organisation.contact_email} style="font-size:12px;color:#6E675A;">{@organisation.contact_email}</span>
            </div>
          </div>

          <%!-- estimate label + prepared for --%>
          <div style="padding:16px 20px;border-bottom:1px solid rgba(52,48,37,0.58);display:flex;gap:20px;align-items:flex-start;">
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Estimate</p>
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:18px;font-weight:700;color:#F4EFE2;margin-top:2px;letter-spacing:-0.02em;">
                {@engagement.scope_title || "Garden estimate"}
              </p>
              <div :if={@engagement.term_start || @engagement.term_end} style="margin-top:10px;display:flex;flex-direction:column;gap:4px;">
                <div :if={@engagement.term_start} style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:#6E675A;width:44px;">Start</span>
                  <span style="font-size:11px;color:#F4EFE2;">{HtmlHelpers.format_date(@engagement.term_start)}</span>
                </div>
                <div :if={@engagement.term_end} style="display:flex;gap:8px;">
                  <span style="font-size:11px;color:#6E675A;width:44px;">End</span>
                  <span style="font-size:11px;color:#F4EFE2;">{HtmlHelpers.format_date(@engagement.term_end)}</span>
                </div>
              </div>
            </div>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Prepared For</p>
              <p style="font-size:14px;font-weight:600;color:#F4EFE2;margin-top:4px;">{portal_customer_name(@current_customer)}</p>
              <p :if={@engagement.garden} style="font-size:12px;color:#9A9384;margin-top:2px;">{@engagement.garden.name}</p>
              <p :if={@current_customer.email} style="font-size:12px;color:#6E675A;margin-top:4px;">{@current_customer.email}</p>
            </div>
          </div>

          <%!-- scope statement --%>
          <div style="padding:16px 20px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">Scope</p>
            <p style="font-size:13px;color:#F4EFE2;line-height:1.6;font-style:italic;">
              {scope_statement(@engagement, @paintings != [])}
            </p>
            <p :if={@engagement.scope_description} style="font-size:13px;color:#9A9384;line-height:1.6;margin-top:8px;">
              {@engagement.scope_description}
            </p>
          </div>

          <%!-- paintings --%>
          <div :if={@paintings != []} style="border-bottom:1px solid rgba(52,48,37,0.58);">
            <div :for={painting <- @paintings}>
              <img src={OpenSauce.Storage.url(painting.storage_key)} style="display:block;width:100%;height:auto;" />
            </div>
          </div>

          <%!-- signature block --%>
          <div style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);">
            <div :if={@engagement.signature} style="display:flex;align-items:center;gap:10px;">
              <div style="width:20px;height:20px;border-radius:50%;border:1.5px solid #54B57E;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                <span style="color:#54B57E;font-size:12px;line-height:1;">✓</span>
              </div>
              <div>
                <p style="font-size:12px;font-weight:600;color:#54B57E;">Signed by {@engagement.signature.signed_by_name}</p>
                <p :if={@engagement.signature.signed_at} style="font-size:11px;color:#6E675A;">
                  {HtmlHelpers.format_date(@engagement.signature.signed_at)}
                </p>
              </div>
            </div>
            <div :if={is_nil(@engagement.signature)} style="border:1px dashed rgba(52,48,37,0.58);border-radius:10px;padding:14px;text-align:center;">
              <p style="font-size:12px;color:#6E675A;">Awaiting signature</p>
            </div>
          </div>

          <%!-- notes --%>
          <div :if={@engagement.notes} style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">Notes</p>
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@engagement.notes}</p>
          </div>

        </div>
      </div>

      <%!-- sticky sign CTA --%>
      <div :if={is_nil(@engagement.signature)} style="position:fixed;bottom:0;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:12px 16px;">
        <div :if={!@signing}>
          <button
            type="button"
            phx-click="start_sign"
            ontouchstart=""
            style="width:100%;background:#54B57E;border:none;border-radius:12px;padding:13px;font-size:15px;font-weight:700;color:#0C1F15;cursor:pointer;"
          >
            Sign this estimate
          </button>
        </div>
        <div :if={@signing}>
          <p style="font-size:12px;color:#9A9384;line-height:1.6;margin-bottom:12px;text-align:center;">
            {consent_text(@engagement, @organisation)}
          </p>
          <div style="display:flex;gap:8px;">
            <button
              type="button"
              phx-click="cancel_sign"
              ontouchstart=""
              style="flex:1;background:rgba(154,147,132,0.1);border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:12px;font-size:14px;font-weight:600;color:#9A9384;cursor:pointer;"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="confirm_sign"
              ontouchstart=""
              style="flex:2;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
            >
              I agree — sign
            </button>
          </div>
        </div>
      </div>

    </div>
    """
  end

  defp scope_statement(%{status: status}, has_painting) do
    drawn_or_described = if has_painting, do: "as digitally rendered", else: "as described"

    case status do
      :in_progress -> "Garden #{drawn_or_described}, installed and maintained."
      :completed -> "Garden #{drawn_or_described}, installed and maintained."
      _ -> "Garden #{drawn_or_described}, proposed for installation and maintenance."
    end
  end

  defp consent_text(engagement, org) do
    title = engagement.scope_title || "this estimate"
    "By signing, I agree to the terms of #{title} as presented by #{org.name}."
  end

  defp portal_customer_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  defp portal_customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"

  defp status_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_style(:proposed), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_style(:signed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_style(:in_progress), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_style(:completed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_style(:cancelled), do: "background:rgba(232,126,126,0.15);color:#E87E7E;"
  defp status_style(_), do: "background:rgba(154,147,132,0.15);color:#9A9384;"
end
