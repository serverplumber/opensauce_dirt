defmodule OpenSauceWeb.PortalLive.Estimate do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:signing, false)
     |> assign(:checked, MapSet.new())}
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
    sign_off_items = socket.assigns.organisation.estimate_sign_off_items || []

    {:noreply,
     socket
     |> assign(:engagement, engagement)
     |> assign(:paintings, paintings)
     |> assign(:sign_off_items, sign_off_items)
     |> assign(:checked, MapSet.new())
     |> assign(:page_title, engagement.scope_title || "Estimate")
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_event("toggle_sign_off", %{"index" => idx}, socket) do
    checked =
      if MapSet.member?(socket.assigns.checked, idx) do
        MapSet.delete(socket.assigns.checked, idx)
      else
        MapSet.put(socket.assigns.checked, idx)
      end

    {:noreply, assign(socket, :checked, checked)}
  end

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

    org = socket.assigns.organisation
    signed_at = DateTime.utc_now()

    agreed_items =
      Enum.map(socket.assigns.sign_off_items, fn item ->
        %{"label" => item["label"], "body" => item["body"]}
      end)

    signature = %{
      signed_by_name: OpenSauce.Portal.customer_name(customer),
      signed_by_email: customer.email,
      signed_at: signed_at,
      signed_from_ip: socket.assigns.portal_peer_ip,
      user_agent: socket.assigns.portal_user_agent,
      engagement_snapshot: %{
        signed_at_iso: DateTime.to_iso8601(signed_at),
        parties: %{
          client: %{name: OpenSauce.Portal.customer_name(customer), email: customer.email},
          contractor: %{name: org.name, legal_name: org.legal_name}
        },
        scope_title: engagement.scope_title,
        scope_description: engagement.scope_description,
        install_price: engagement.install_price && Decimal.to_string(engagement.install_price),
        maintenance_price_annual:
          engagement.maintenance_price_annual &&
            Decimal.to_string(engagement.maintenance_price_annual),
        term_start: engagement.term_start && Date.to_iso8601(engagement.term_start),
        term_end: engagement.term_end && Date.to_iso8601(engagement.term_end),
        paintings:
          Enum.map(socket.assigns.paintings, fn p ->
            %{
              filename: p.original_filename,
              storage_key: p.storage_key,
              sha256: p.content_hash
            }
          end),
        payment_info: org.payment_info,
        invoice_terms: org.invoice_terms
      },
      agreed_items: agreed_items,
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

          <%!-- paintings — contract scope images --%>
          <div :if={@paintings != []} style="border-bottom:1px solid rgba(52,48,37,0.58);">
            <div style="padding:12px 20px 10px;background:rgba(84,181,126,0.05);border-bottom:1px solid rgba(84,181,126,0.15);">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#54B57E;">Garden as digitally rendered</p>
              <p style="font-size:11px;color:#9A9384;margin-top:3px;line-height:1.4;">The images below show the exact scope of this engagement. By signing, you confirm these renderings reflect the agreed design.</p>
            </div>
            <div :for={painting <- @paintings}>
              <img src={HtmlHelpers.storage_url(painting.storage_key)} style="display:block;width:100%;height:auto;" />
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
      <div :if={is_nil(@engagement.signature)} style="position:fixed;bottom:0;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);">

        <%!-- normal mode: checkboxes + sign button --%>
        <div :if={!@signing}>
          <%!-- scrollable sign-off checklist --%>
          <div :if={@sign_off_items != []}
            style="max-height:40vh;overflow-y:auto;padding:12px 16px 8px;display:flex;flex-direction:column;gap:10px;border-bottom:1px solid rgba(52,48,37,0.4);">
            <div :for={{item, idx} <- Enum.with_index(@sign_off_items)}>
              <div :if={item["body"]}
                style="font-size:11.5px;color:#9A9384;line-height:1.55;margin-bottom:6px;padding:10px 12px;background:rgba(255,255,255,0.03);border-radius:10px;border:1px solid rgba(52,48,37,0.58);white-space:pre-line;">
                {item["body"]}
              </div>
              <button
                type="button"
                phx-click="toggle_sign_off"
                phx-value-index={idx}
                ontouchstart=""
                style="width:100%;display:flex;align-items:flex-start;gap:10px;background:none;border:none;padding:0;cursor:pointer;text-align:left;"
              >
                <div style={"width:22px;height:22px;border-radius:6px;flex-shrink:0;margin-top:1px;transition:all 0.1s;border:1.5px solid #{if MapSet.member?(@checked, to_string(idx)), do: "#54B57E", else: "rgba(110,103,90,0.6)"};background:#{if MapSet.member?(@checked, to_string(idx)), do: "#54B57E", else: "transparent"};display:flex;align-items:center;justify-content:center;"}>
                  <span :if={MapSet.member?(@checked, to_string(idx))} style="color:#0C1F15;font-size:13px;font-weight:800;line-height:1;">✓</span>
                </div>
                <span style="font-size:13px;color:#F4EFE2;line-height:1.5;">{item["label"]}</span>
              </button>
            </div>
          </div>

          <div style="padding:10px 16px 12px;padding-bottom:max(12px,env(safe-area-inset-bottom));">
            <button
              type="button"
              phx-click="start_sign"
              ontouchstart=""
              disabled={not all_checked?(@checked, @sign_off_items)}
              style={"width:100%;border:none;border-radius:12px;padding:14px;font-size:15px;font-weight:700;cursor:#{if all_checked?(@checked, @sign_off_items), do: "pointer", else: "default"};transition:all 0.15s;#{if all_checked?(@checked, @sign_off_items), do: "background:#54B57E;color:#0C1F15;", else: "background:rgba(52,48,37,0.8);color:#6E675A;"}"}
            >
              Sign this estimate
            </button>
          </div>
        </div>

        <%!-- confirmation mode --%>
        <div :if={@signing} style="padding:12px 16px;padding-bottom:max(12px,env(safe-area-inset-bottom));">
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
    "By signing, I confirm I have reviewed the scope#{if engagement.images != [] and Enum.any?(engagement.images, &(&1.type == :painting)), do: " and digital renderings", else: ""} above and agree to the terms of #{title} as presented by #{org.name}."
  end

  defp portal_customer_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  defp portal_customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"

  defp all_checked?(_checked, []), do: true

  defp all_checked?(checked, items) do
    Enum.all?(0..(length(items) - 1)//1, &MapSet.member?(checked, to_string(&1)))
  end

  defp status_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_style(:proposed), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_style(:signed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_style(:in_progress), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_style(:completed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_style(:cancelled), do: "background:rgba(232,126,126,0.15);color:#E87E7E;"
  defp status_style(_), do: "background:rgba(154,147,132,0.15);color:#9A9384;"
end
