defmodule OpenSauceWeb.EngagementLive.Estimate do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import OpenSauceWeb.EstimateDocument

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"reference" => reference, "engagement_id" => engagement_id} = params, _uri, socket) do
    member = socket.assigns.current_member

    return_to =
      Map.get(
        params,
        "return_to",
        ~p"/manage/customers/#{reference}/engagements/#{engagement_id}"
      )

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
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:var(--s-text,#F4EFE2);-webkit-font-smoothing:antialiased;padding-bottom:100px;">
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
        <p style="flex:1;font-size:13px;font-weight:600;color:var(--s-muted,#9A9384);">Estimate</p>
        <span style={"#{status_badge_style(@engagement.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
          {Phoenix.Naming.humanize(@engagement.status)}
        </span>
      </div>

      <%!-- estimate document — --s-* vars render it in the org's chosen mode,
           exactly as the customer sees it; staff chrome outside stays soil --%>
      <.estimate_document
        engagement={@engagement}
        organisation={@organisation}
        customer={@engagement.customer}
        paintings={@paintings}
      />

      <%!-- sticky send CTA --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:var(--s-bg,#16140E);border-top:1px solid var(--s-border,rgba(52,48,37,0.58));padding:10px 16px;">
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

    OpenSauce.Portal.send_resource_link(
      customer,
      socket.assigns.organisation,
      "estimate",
      engagement.id
    )

    {:noreply, put_flash(socket, :info, "Estimate link sent to #{customer.email}.")}
  end

  defp status_badge_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:proposed), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_badge_style(:signed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:in_progress), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:completed), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(:cancelled), do: "background:rgba(232,126,126,0.15);color:#E87E7E;"

  defp status_badge_style(_), do: "background:rgba(154,147,132,0.15);color:var(--s-muted,#9A9384);"
end
