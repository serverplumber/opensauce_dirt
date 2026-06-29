defmodule OpenSauceWeb.EngagementLive.Estimate do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"reference" => reference, "engagement_id" => engagement_id} = params, _uri, socket) do
    member = socket.assigns.current_member
    return_to = Map.get(params, "return_to", ~p"/manage/customers/#{reference}/engagements/#{engagement_id}")

    engagement =
      Ash.get!(OpenSauce.CRM.Engagement, engagement_id,
        actor: member,
        tenant: member.organisation_id,
        load: [:customer, :garden, :images]
      )

    paintings = Enum.filter(engagement.images, &(&1.type == :painting))

    {:noreply,
     socket
     |> assign(:reference, reference)
     |> assign(:return_to, return_to)
     |> assign(:engagement, engagement)
     |> assign(:paintings, paintings)
     |> assign(:page_title, "Estimate — #{engagement.scope_title || "Engagement"}")
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:100px;">

      <%!-- top bar --%>
      <div style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;">
        <.link navigate={@return_to}>
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
        <p style="flex:1;font-size:13px;font-weight:600;color:#9A9384;">Estimate</p>
        <span style={"#{status_badge_style(@engagement.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
          {Phoenix.Naming.humanize(@engagement.status)}
        </span>
      </div>

      <%!-- estimate document --%>
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

          <%!-- estimate label + prepared for --%>
          <div style="padding:16px 20px;border-bottom:1px solid rgba(52,48,37,0.58);display:flex;gap:20px;align-items:flex-start;">
            <%!-- left: document type + dates --%>
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
            <%!-- right: prepared for --%>
            <div style="flex:1;min-width:0;">
              <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;">Prepared For</p>
              <p style="font-size:14px;font-weight:600;color:#F4EFE2;margin-top:4px;">{customer_name(@engagement.customer)}</p>
              <p :if={@engagement.garden} style="font-size:12px;color:#9A9384;margin-top:2px;">{@engagement.garden.name}</p>
              <p :if={@engagement.customer && @engagement.customer.email} style="font-size:12px;color:#6E675A;margin-top:4px;">
                {@engagement.customer.email}
              </p>
            </div>
          </div>

          <%!-- scope description --%>
          <div style="padding:16px 20px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">Scope</p>
            <p style="font-size:13px;color:#F4EFE2;line-height:1.6;font-style:italic;">
              {scope_statement(@engagement, @paintings != [])}
            </p>
            <p :if={@engagement.scope_description} style="font-size:13px;color:#9A9384;line-height:1.6;margin-top:8px;">
              {@engagement.scope_description}
            </p>
          </div>

          <%!-- garden drawings — each painting is part of the contract document --%>
          <div :if={@paintings != []} style="border-bottom:1px solid rgba(52,48,37,0.58);">
            <div :for={painting <- @paintings}>
              <img
                src={HtmlHelpers.storage_url(painting.storage_key)}
                style="display:block;width:100%;height:auto;"
              />
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
              <p style="font-size:12px;color:#6E675A;">Awaiting client signature</p>
            </div>
          </div>

          <%!-- notes --%>
          <div :if={@engagement.notes} style="padding:14px 20px;border-top:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#6E675A;margin-bottom:6px;">Notes</p>
            <p style="font-size:12px;color:#9A9384;white-space:pre-line;">{@engagement.notes}</p>
          </div>

        </div>
      </div>

      <%!-- sticky send CTA --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;">
        <button
          type="button"
          phx-click="send_to_client"
          ontouchstart=""
          style="width:100%;background:rgba(84,181,126,0.08);border:1px solid rgba(84,181,126,0.3);border-radius:12px;padding:12px;font-size:14px;font-weight:600;color:#54B57E;cursor:pointer;"
        >
          Send to Client
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("send_to_client", _params, socket) do
    engagement = socket.assigns.engagement
    member = socket.assigns.current_member

    customer =
      Ash.get!(OpenSauce.CRM.Customer, engagement.customer_id,
        actor: member,
        tenant: member.organisation_id
      )

    OpenSauce.Portal.send_resource_link(customer, socket.assigns.organisation, "estimate", engagement.id)
    {:noreply, put_flash(socket, :info, "Estimate link sent to #{customer.email}.")}
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

  defp status_badge_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:proposed), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_badge_style(:signed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:in_progress), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:completed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:cancelled), do: "background:rgba(232,126,126,0.15);color:#E87E7E;"
  defp status_badge_style(_), do: "background:rgba(154,147,132,0.15);color:#9A9384;"
end
