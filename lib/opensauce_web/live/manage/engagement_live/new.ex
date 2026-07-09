defmodule OpenSauceWeb.EngagementLive.New do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.EngagementLive.FormComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"reference" => reference} = params, _uri, socket) do
    member = socket.assigns.current_member

    customer =
      CRM.get_customer_by_reference!(reference,
        actor: member,
        tenant: member.organisation_id,
        load: [:full_name, :garden_addresses]
      )

    engagement =
      case params["engagement_id"] do
        nil ->
          nil

        id ->
          Ash.get!(CRM.Engagement, id,
            actor: member,
            tenant: member.organisation_id
          )
      end

    back_to =
      case params["engagement_id"] do
        nil -> ~p"/manage/customers/#{reference}"
        id -> ~p"/manage/customers/#{reference}/engagements/#{id}"
      end

    socket =
      socket
      |> assign(:customer, customer)
      |> assign(:engagement, engagement)
      |> assign(:back_to, back_to)
      |> assign(:page_title, if(engagement, do: "Edit Engagement", else: "New Engagement"))
      |> assign(:main_bg, "bg-[#16140E]")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- nav row --%>
      <div style="display:flex;align-items:center;gap:8px;padding:12px 16px 0;">
        <.link navigate={@back_to}>
          <button
            type="button"
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            ontouchstart=""
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M19 12H5M12 19l-7-7 7-7"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </button>
        </.link>
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:18px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0;">
          {if @engagement, do: "Edit Engagement", else: "New Engagement"}
        </h1>
      </div>

      <div style="padding:16px 16px 120px;">
        <.live_component
          module={OpenSauceWeb.EngagementLive.FormComponent}
          id={if @engagement, do: @engagement.id, else: "new"}
          current_member={@current_member}
          engagement={@engagement}
          customer={@customer}
          currency={@organisation.currency}
          navigate={@back_to}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({FormComponent, {:saved_navigate, _engagement, dest}}, socket) do
    {:noreply, socket |> put_flash(:info, "Engagement saved.") |> push_navigate(to: dest)}
  end

  def handle_info({FormComponent, {:saved, _engagement}}, socket) do
    {:noreply, socket}
  end
end
