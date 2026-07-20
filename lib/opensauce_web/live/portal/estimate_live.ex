defmodule OpenSauceWeb.PortalLive.Estimate do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import OpenSauceWeb.EstimateDocument

  alias OpenSauce.BrandTheme
  alias OpenSauce.CRM

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
    brand = BrandTheme.scheme(socket.assigns.organisation)

    {:noreply,
     socket
     |> assign(:engagement, engagement)
     |> assign(:paintings, paintings)
     |> assign(:sign_off_items, sign_off_items)
     |> assign(:checked, MapSet.new())
     |> assign(:page_title, engagement.scope_title || "Estimate")
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:brand, brand)
     |> assign(:accent, brand.primary)
     |> assign(:on_accent, brand.on_primary)}
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
      |> Ash.Changeset.for_update(:sign, %{signature: signature},
        authorize?: false,
        tenant: org_id
      )
      |> Ash.update()

    {:noreply,
     socket
     |> assign(:engagement, signed)
     |> assign(:signing, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style={"font-family:'Hanken Grotesk',system-ui,sans-serif;-webkit-font-smoothing:antialiased;padding-bottom:120px;min-height:100dvh;color:#{@brand.text};background:#{@brand.bg};--s-bg:#{@brand.bg};--s-paper:#{@brand.paper};--s-border:#{BrandTheme.rgba(@brand.border, 0.58)};--s-text:#{@brand.text};--s-muted:#{@brand.muted};--s-dim:#{@brand.dim};"}>
      <%!-- minimal top bar --%>
      <div style="padding:16px 16px 10px;">
        <p style={"font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;letter-spacing:-0.02em;color:#{@accent};"}>
          {@organisation.name}
        </p>
      </div>

      <%!-- document --%>
      <.estimate_document
        engagement={@engagement}
        organisation={@organisation}
        customer={@current_customer}
        paintings={@paintings}
        signable
      />

      <%!-- sticky sign CTA --%>
      <div
        :if={is_nil(@engagement.signature)}
        style="position:fixed;bottom:0;left:0;right:0;background:var(--s-bg,#16140E);border-top:1px solid var(--s-border,rgba(52,48,37,0.58));"
      >
        <%!-- normal mode: checkboxes + sign button --%>
        <div :if={!@signing}>
          <%!-- scrollable sign-off checklist --%>
          <div
            :if={@sign_off_items != []}
            style="max-height:40vh;overflow-y:auto;padding:12px 16px 8px;display:flex;flex-direction:column;gap:10px;border-bottom:1px solid var(--s-border,rgba(52,48,37,0.4));"
          >
            <div :for={{item, idx} <- Enum.with_index(@sign_off_items)}>
              <div
                :if={item["body"]}
                style="font-size:11.5px;color:var(--s-muted,#9A9384);line-height:1.55;margin-bottom:6px;padding:10px 12px;background:var(--s-bg,#16140E);border-radius:10px;border:1px solid var(--s-border,rgba(52,48,37,0.58));white-space:pre-line;"
              >
                {item["body"]}
              </div>
              <button
                type="button"
                phx-click="toggle_sign_off"
                phx-value-index={idx}
                ontouchstart=""
                style="width:100%;display:flex;align-items:flex-start;gap:10px;background:none;border:none;padding:0;cursor:pointer;text-align:left;"
              >
                <div style={"width:22px;height:22px;border-radius:6px;flex-shrink:0;margin-top:1px;transition:all 0.1s;border:1.5px solid #{if MapSet.member?(@checked, to_string(idx)), do: @accent, else: "rgba(110,103,90,0.6)"};background:#{if MapSet.member?(@checked, to_string(idx)), do: @accent, else: "transparent"};display:flex;align-items:center;justify-content:center;"}>
                  <span
                    :if={MapSet.member?(@checked, to_string(idx))}
                    style={"color:#{@on_accent};font-size:13px;font-weight:800;line-height:1;"}
                  >
                    ✓
                  </span>
                </div>
                <span style="font-size:13px;color:var(--s-text,#F4EFE2);line-height:1.5;">
                  {item["label"]}
                </span>
              </button>
            </div>
          </div>

          <div style="padding:10px 16px 12px;padding-bottom:max(12px,env(safe-area-inset-bottom));">
            <button
              type="button"
              phx-click="start_sign"
              ontouchstart=""
              disabled={not all_checked?(@checked, @sign_off_items)}
              style={"width:100%;border:none;border-radius:12px;padding:14px;font-size:15px;font-weight:700;cursor:#{if all_checked?(@checked, @sign_off_items), do: "pointer", else: "default"};transition:all 0.15s;#{if all_checked?(@checked, @sign_off_items), do: "background:#{@accent};color:#{@on_accent};", else: "background:rgba(52,48,37,0.8);color:var(--s-dim,#6E675A);"}"}
            >
              Sign this estimate
            </button>
          </div>
        </div>

        <%!-- confirmation mode --%>
        <div
          :if={@signing}
          style="padding:12px 16px;padding-bottom:max(12px,env(safe-area-inset-bottom));"
        >
          <p style="font-size:12px;color:var(--s-muted,#9A9384);line-height:1.6;margin-bottom:12px;text-align:center;">
            {consent_text(@engagement, @organisation)}
          </p>
          <div style="display:flex;gap:8px;">
            <button
              type="button"
              phx-click="cancel_sign"
              ontouchstart=""
              style="flex:1;background:rgba(154,147,132,0.1);border:1px solid var(--s-border,rgba(52,48,37,0.58));border-radius:12px;padding:12px;font-size:14px;font-weight:600;color:var(--s-muted,#9A9384);cursor:pointer;"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="confirm_sign"
              ontouchstart=""
              style={"flex:2;background:#{@accent};border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#{@on_accent};cursor:pointer;"}
            >
              I agree — sign
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp consent_text(engagement, org) do
    title = engagement.scope_title || "this estimate"

    "By signing, I confirm I have reviewed the scope#{if engagement.images != [] and Enum.any?(engagement.images, &(&1.type == :painting)), do: " and digital renderings", else: ""} above and agree to the terms of #{title} as presented by #{org.name}."
  end

  defp all_checked?(_checked, []), do: true

  defp all_checked?(checked, items) do
    Enum.all?(0..(length(items) - 1)//1, &MapSet.member?(checked, to_string(&1)))
  end
end
