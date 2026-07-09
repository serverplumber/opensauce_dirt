defmodule OpenSauceWeb.PurchasingLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias Decimal, as: D
  alias OpenSauce.Inventory
  alias OpenSauce.Inventory.UpdatePurchaseOrders

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- header --%>
      <div style="padding:12px 16px 14px;display:flex;align-items:flex-start;justify-content:space-between;">
        <div>
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;">
            Purchasing
          </h1>
          <p style="font-size:13px;color:#9A9384;margin-top:3px;">
            Purchase orders and supplier runs.
          </p>
        </div>
        <.link navigate={~p"/manage/purchasing/suppliers"}>
          <button
            type="button"
            ontouchstart=""
            style="margin-top:4px;color:#6E675A;background:rgba(52,48,37,0.5);border:1px solid rgba(52,48,37,0.58);border-radius:10px;padding:6px 11px;font-size:12px;font-weight:600;cursor:pointer;"
          >
            Suppliers
          </button>
        </.link>
      </div>

      <%!-- sync from jobs row --%>
      <div style="padding:0 16px 12px;">
        <button
          type="button"
          phx-click="sync_from_jobs"
          ontouchstart=""
          disabled={@syncing}
          style={"width:100%;background:rgba(52,48,37,0.45);border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:11px 14px;display:flex;align-items:center;justify-content:space-between;cursor:pointer;#{if @syncing, do: "opacity:0.5;", else: ""}"}
        >
          <div style="display:flex;align-items:center;gap:9px;">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none">
              <path
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                stroke="#54B57E"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
            <span style="font-size:14px;font-weight:600;color:#F4EFE2;">
              {if @syncing, do: "Syncing…", else: "Sync from jobs"}
            </span>
          </div>
          <span style="font-size:12px;color:#6E675A;">
            {if @sync_flash, do: @sync_flash, else: "pull upcoming job materials"}
          </span>
        </button>
      </div>

      <%!-- draft POs --%>
      <div :if={@drafts != []} style="padding:0 16px 8px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          {draft_label(length(@drafts))}
        </p>
        <div style="display:flex;flex-direction:column;gap:10px;">
          <div
            :for={po <- @drafts}
            style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px;"
          >
            <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
              <div style="min-width:0;flex:1;">
                <p style="font-size:15.5px;font-weight:700;letter-spacing:-0.01em;color:#F4EFE2;">
                  {po_supplier_name(po)}
                </p>
                <p style="font-size:12px;color:#9A9384;margin-top:3px;">
                  {po_summary(po, @organisation.currency)}
                </p>
              </div>
              <span style="flex-shrink:0;background:rgba(219,146,88,0.15);color:#DB9258;border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;">
                draft
              </span>
            </div>
            <div style="display:flex;gap:8px;margin-top:12px;">
              <.link navigate={~p"/manage/purchasing/#{po.reference}"} style="flex:1;">
                <button
                  type="button"
                  ontouchstart=""
                  style="width:100%;background:rgba(52,48,37,0.5);border:1px solid rgba(52,48,37,0.58);border-radius:10px;padding:8px;font-size:13px;font-weight:600;color:#F4EFE2;cursor:pointer;"
                >
                  Edit
                </button>
              </.link>
              <button
                type="button"
                phx-click="send_po"
                phx-value-id={po.id}
                ontouchstart=""
                style="flex:1;background:#54B57E;border:none;border-radius:10px;padding:8px;font-size:13px;font-weight:700;color:#0C1F15;cursor:pointer;"
              >
                Send
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- in-transit POs --%>
      <div :if={@in_transit != []} style="padding:8px 16px 8px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          in transit
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.link :for={po <- @in_transit} navigate={~p"/manage/purchasing/#{po.reference}"}>
            <div
              style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between;"
              ontouchstart=""
            >
              <div>
                <p style="font-size:14.5px;font-weight:700;color:#F4EFE2;">{po_supplier_name(po)}</p>
                <p style="font-size:12px;color:#9A9384;margin-top:2px;">
                  {po_summary(po, @organisation.currency)}
                </p>
              </div>
              <div style="display:flex;align-items:center;gap:8px;">
                <span style={"background:#{transit_badge_bg(po.status)};color:#{transit_badge_fg(po.status)};border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
                  {status_label(po.status)}
                </span>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                  <path d="M9 6l6 6-6 6" stroke="#6E675A" stroke-width="2" stroke-linecap="round" />
                </svg>
              </div>
            </div>
          </.link>
        </div>
      </div>

      <%!-- recently received --%>
      <div :if={@recent != []} style="padding:8px 16px 100px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
          recently received
        </p>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <.link :for={po <- @recent} navigate={~p"/manage/purchasing/#{po.reference}"}>
            <div
              style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between;opacity:0.7;"
              ontouchstart=""
            >
              <div>
                <p style="font-size:14px;font-weight:600;color:#F4EFE2;">{po_supplier_name(po)}</p>
                <p style="font-size:12px;color:#9A9384;margin-top:2px;">{po.reference}</p>
              </div>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path d="M9 6l6 6-6 6" stroke="#6E675A" stroke-width="2" stroke-linecap="round" />
              </svg>
            </div>
          </.link>
        </div>
      </div>

      <%!-- empty state --%>
      <div
        :if={@drafts == [] and @in_transit == [] and @recent == []}
        style="padding:60px 16px;text-align:center;"
      >
        <p style="font-size:15px;color:#6E675A;">No purchase orders yet.</p>
        <p style="font-size:13px;color:#6E675A;margin-top:6px;">
          Sync from jobs to build your first supply run.
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:syncing, false)
     |> assign(:sync_flash, nil)
     |> load_pos()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Purchasing")
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_event("sync_from_jobs", _params, socket) do
    member = socket.assigns.current_member

    socket = assign(socket, :syncing, true)

    case UpdatePurchaseOrders.run(actor: member, tenant: member.organisation_id) do
      {:ok, 0} ->
        {:noreply,
         socket
         |> assign(:syncing, false)
         |> assign(:sync_flash, "already up to date")}

      {:ok, n} ->
        {:noreply,
         socket
         |> assign(:syncing, false)
         |> assign(:sync_flash, "added #{n} item(s)")
         |> load_pos()}
    end
  end

  @impl true
  def handle_event("send_po", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    po = Inventory.get_purchase_order_by_id!(id, opts)

    case Inventory.mark_purchase_order_ordered(po, opts) do
      {:ok, _} ->
        {:noreply, load_pos(socket)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp load_pos(socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id, load: [:supplier, items: []]]

    all = Inventory.list_purchase_orders!(opts)

    drafts = Enum.filter(all, &(&1.status == :draft))
    in_transit = Enum.filter(all, &(&1.status in [:ordered, :confirmed]))
    recent = all |> Enum.filter(&(&1.status == :received)) |> Enum.take(5)

    assign(socket, drafts: drafts, in_transit: in_transit, recent: recent)
  end

  defp po_supplier_name(%{supplier: %{name: name}}), do: name
  defp po_supplier_name(_), do: "Unassigned"

  defp po_summary(po, currency) do
    count = length(po.items)

    total =
      Enum.reduce(po.items, D.new(0), fn item, acc ->
        price = item.cost || D.new(0)
        qty = item.quantity || D.new(0)
        D.add(acc, D.mult(price, qty))
      end)

    item_str = if count == 1, do: "1 item", else: "#{count} items"

    if D.gt?(total, D.new(0)) do
      "#{item_str} · est #{format_money(currency, total)}"
    else
      item_str
    end
  end

  defp draft_label(1), do: "1 draft"
  defp draft_label(n), do: "#{n} drafts"

  defp status_label(:ordered), do: "ordered"
  defp status_label(:confirmed), do: "confirmed"
  defp status_label(s), do: to_string(s)

  defp transit_badge_bg(:ordered), do: "rgba(219,146,88,0.15)"
  defp transit_badge_bg(:confirmed), do: "rgba(90,180,216,0.15)"
  defp transit_badge_bg(_), do: "rgba(154,147,132,0.15)"

  defp transit_badge_fg(:ordered), do: "#DB9258"
  defp transit_badge_fg(:confirmed), do: "#5AB4D8"
  defp transit_badge_fg(_), do: "#9A9384"
end
