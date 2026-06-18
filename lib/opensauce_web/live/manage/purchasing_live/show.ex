defmodule OpenSauceWeb.PurchasingLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias Decimal, as: D
  alias OpenSauce.Accounts
  alias OpenSauce.Inventory
  alias OpenSauce.Inventory.Receiving

  import OpenSauceWeb.PurchaseOrderPrint

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- print-only sheet (hidden on mobile) --%>
      <div class="hidden print:block">
        <.purchase_order_print po={@po} currency={@organisation.currency} organisation={@organisation} />
      </div>

      <div class="print:hidden">
        <%!-- top bar --%>
        <div style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;">
          <.link navigate={~p"/manage/purchasing"}>
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
          <div style="flex:1;min-width:0;">
            <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:19px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
              {po_supplier_name(@po)}
            </h1>
            <p style="font-size:12px;color:#6E675A;margin-top:1px;font-family:monospace;">{@po.reference}</p>
          </div>
          <div style="display:flex;align-items:center;gap:6px;">
            <span style={"#{status_badge_style(@po.status)}border-radius:20px;padding:3px 10px;font-size:11px;font-weight:700;"}>
              {status_label(@po.status)}
            </span>
            <button
              :if={@po.status in [:draft, :ordered]}
              type="button"
              onclick="window.print()"
              ontouchstart=""
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none">
                <path
                  d="M6 9V2h12v7M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2M6 14h12v8H6z"
                  stroke="currentColor"
                  stroke-width="1.8"
                  stroke-linecap="round"
                />
              </svg>
            </button>
          </div>
        </div>

        <%!-- PO detail view: show / items / add_item --%>
        <div :if={@live_action in [:show, :items, :add_item]}>
          <%!-- ordered / confirmed date chips --%>
          <div
            :if={@po.ordered_at || @po.received_at}
            style="padding:0 16px 12px;display:flex;gap:8px;"
          >
            <span :if={@po.ordered_at} style="background:rgba(52,48,37,0.5);border-radius:20px;padding:3px 10px;font-size:11px;color:#9A9384;">
              sent {fmt_date(@po.ordered_at)}
            </span>
            <span :if={@po.received_at} style="background:rgba(52,48,37,0.5);border-radius:20px;padding:3px 10px;font-size:11px;color:#9A9384;">
              received {fmt_date(@po.received_at)}
            </span>
          </div>

          <%!-- ordered: inline confirmation form --%>
          <div :if={@po.status == :ordered} style="padding:0 16px 10px;">
            <p style="font-size:13px;color:#9A9384;margin-bottom:12px;">
              Enter the quantity the supplier confirmed they have set aside.
            </p>
            <form phx-submit="confirm_items" id="confirm-form" style="display:flex;flex-direction:column;gap:8px;">
              <div
                :for={item <- @po.items}
                style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;"
              >
                <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
                  <div style="min-width:0;flex:1;">
                    <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;">{plant_label(item)}</p>
                    <p style="font-size:11.5px;font-family:monospace;color:#6E675A;margin-top:2px;">{item.supplier_sku}</p>
                  </div>
                  <span :if={item.is_reservation} style="flex-shrink:0;background:rgba(90,180,216,0.15);color:#5AB4D8;border-radius:12px;padding:2px 8px;font-size:10px;font-weight:700;">
                    cherry-pick
                  </span>
                </div>
                <div style="display:flex;align-items:center;justify-content:space-between;margin-top:10px;">
                  <span style="font-size:12px;color:#9A9384;">ordered: <span style="color:#F4EFE2;font-weight:600;">{fmt_qty(item.quantity)}</span></span>
                  <div style="display:flex;align-items:center;gap:8px;">
                    <label style="font-size:12px;color:#9A9384;">confirmed:</label>
                    <input
                      type="number"
                      name={"confirm[#{item.id}]"}
                      value={fmt_qty(item.confirmed_qty || item.quantity)}
                      step="1"
                      min="0"
                      style="width:70px;background:#16140E;border:1px solid rgba(52,48,37,0.8);border-radius:8px;padding:5px 8px;font-size:14px;font-weight:600;color:#F4EFE2;text-align:right;"
                    />
                  </div>
                </div>
              </div>
              <div style="height:90px;" />
              <div style="position:fixed;bottom:74px;left:0;right:0;padding:12px 16px;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);">
                <button
                  type="submit"
                  style="width:100%;background:#54B57E;border:none;border-radius:14px;padding:14px;font-size:15px;font-weight:700;color:#0C1F15;cursor:pointer;"
                >
                  Supplier confirmed →
                </button>
              </div>
            </form>
          </div>

          <%!-- items list (non-ordered states) --%>
          <div :if={@po.status != :ordered} style="padding:0 16px;display:flex;flex-direction:column;gap:8px;">
            <p
              :if={@po.items == []}
              style="font-size:13.5px;color:#6E675A;text-align:center;padding:32px 0;"
            >
              No items yet
            </p>
            <div
              :for={item <- @po.items}
              style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;"
            >
              <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
                <div style="min-width:0;flex:1;">
                  <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;">{plant_label(item)}</p>
                  <p style="font-size:11.5px;font-family:monospace;color:#6E675A;margin-top:2px;">{item.supplier_sku}</p>
                </div>
                <span :if={item.is_reservation} style="flex-shrink:0;background:rgba(90,180,216,0.15);color:#5AB4D8;border-radius:12px;padding:2px 8px;font-size:10px;font-weight:700;">
                  cherry-pick
                </span>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;margin-top:8px;">
                <div style="display:flex;gap:12px;">
                  <span style="font-size:12px;color:#9A9384;">
                    ordered: <span style="color:#F4EFE2;font-weight:600;">{fmt_qty(item.quantity)}</span>
                  </span>
                  <span :if={item.confirmed_qty} style="font-size:12px;color:#9A9384;">
                    confirmed: <span style="color:#F4EFE2;font-weight:600;">{fmt_qty(item.confirmed_qty)}</span>
                  </span>
                  <span :if={item.received_qty} style="font-size:12px;color:#9A9384;">
                    received: <span style="color:#54B57E;font-weight:600;">{fmt_qty(item.received_qty)}</span>
                  </span>
                </div>
                <span :if={item.unit_price} style="font-size:12px;color:#6E675A;">
                  {format_money(@organisation.currency, item.unit_price)}
                </span>
              </div>
            </div>
          </div>

          <%!-- spacer for sticky CTA --%>
          <div :if={@po.status != :ordered} style="height:110px;" />

          <%!-- sticky CTA --%>
          <div
            :if={@po.status in [:draft, :confirmed]}
            style="position:fixed;bottom:74px;left:0;right:0;padding:12px 16px;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);"
          >
            <div :if={@po.status == :draft} style="display:flex;gap:8px;">
              <.link
                patch={~p"/manage/purchasing/#{@po.reference}/add_item"}
                style="flex-shrink:0;"
              >
                <button
                  type="button"
                  ontouchstart=""
                  style="height:50px;padding:0 16px;background:rgba(52,48,37,0.5);border:1px solid rgba(52,48,37,0.58);border-radius:14px;font-size:14px;font-weight:600;color:#F4EFE2;cursor:pointer;white-space:nowrap;"
                >
                  + Add item
                </button>
              </.link>
              <button
                type="button"
                phx-click="mark_ordered"
                ontouchstart=""
                style="flex:1;height:50px;background:#54B57E;border:none;border-radius:14px;font-size:15px;font-weight:700;color:#0C1F15;cursor:pointer;"
              >
                Send order →
              </button>
            </div>
            <.link :if={@po.status == :confirmed} navigate={~p"/manage/purchasing/#{@po.reference}/lineup"}>
              <button
                type="button"
                ontouchstart=""
                style="width:100%;height:50px;background:#54B57E;border:none;border-radius:14px;font-size:15px;font-weight:700;color:#0C1F15;cursor:pointer;"
              >
                Go to pickup →
              </button>
            </.link>
          </div>
        </div>

        <%!-- F3 lineup / pickup screen --%>
        <div :if={@live_action == :lineup}>
          <div :if={@po.status == :confirmed} style="padding:0 16px;display:flex;flex-direction:column;gap:10px;">
            <%!-- supplier hero --%>
            <div style="background:#211E16;border:2px solid #54B57E;border-radius:16px;padding:14px;">
              <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#54B57E;margin-bottom:4px;">
                pickup job
              </p>
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:19px;font-weight:700;color:#F4EFE2;letter-spacing:-0.02em;">
                {po_supplier_name(@po)}
              </p>
              <p
                :for={addr <- List.wrap(@po.supplier && @po.supplier.addresses)}
                style="font-size:13px;color:#9A9384;margin-top:2px;"
              >
                {addr_short(addr)}
              </p>
              <p style="font-size:12px;color:#6E675A;margin-top:4px;">
                PO {@po.reference} · {@po.items |> length()} items
              </p>
            </div>

            <%!-- tick-as-you-load checklist --%>
            <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-top:4px;">
              collect — tick as you load
            </p>

            <form phx-submit="finalize_pickup" id="lineup-form" style="display:flex;flex-direction:column;gap:8px;">
              <div
                :for={item <- @po.items}
                style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;"
              >
                <div style="display:flex;align-items:center;gap:12px;">
                  <div style="flex:1;min-width:0;">
                    <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;">{plant_label(item)}</p>
                    <div style="display:flex;align-items:center;gap:8px;margin-top:4px;">
                      <p style="font-size:12px;color:#9A9384;">
                        confirmed: <span style="color:#F4EFE2;font-weight:600;">{fmt_qty(item.confirmed_qty || item.quantity)}</span>
                      </p>
                      <span :if={item.is_reservation} style="background:rgba(90,180,216,0.15);color:#5AB4D8;border-radius:12px;padding:1px 7px;font-size:10px;font-weight:700;">
                        cherry-pick
                      </span>
                    </div>
                  </div>
                  <div style="display:flex;align-items:center;gap:6px;flex-shrink:0;">
                    <label style="font-size:12px;color:#6E675A;">taking</label>
                    <input
                      type="number"
                      name={"lineup[#{item.id}]"}
                      value={fmt_qty(item.confirmed_qty || item.quantity)}
                      step="1"
                      min="0"
                      style="width:64px;background:#16140E;border:1px solid rgba(52,48,37,0.8);border-radius:8px;padding:5px 8px;font-size:14px;font-weight:700;color:#F4EFE2;text-align:right;"
                    />
                  </div>
                </div>
              </div>

              <div style="height:90px;" />

              <div style="position:fixed;bottom:74px;left:0;right:0;padding:12px 16px;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);">
                <button
                  type="submit"
                  style="width:100%;background:#54B57E;border:none;border-radius:14px;padding:14px;font-size:15px;font-weight:700;color:#0C1F15;cursor:pointer;"
                >
                  Received & on truck →
                </button>
              </div>
            </form>
          </div>

          <div :if={@po.status == :received} style="padding:0 16px;display:flex;flex-direction:column;gap:8px;">
            <div
              :for={item <- @po.items}
              style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;opacity:0.85;"
            >
              <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;">{plant_label(item)}</p>
              <div style="display:flex;gap:12px;margin-top:6px;">
                <span style="font-size:12px;color:#9A9384;">
                  confirmed: <span style="color:#F4EFE2;font-weight:600;">{fmt_qty(item.confirmed_qty)}</span>
                </span>
                <span style="font-size:12px;color:#9A9384;">
                  received: <span style="color:#54B57E;font-weight:600;">{fmt_qty(item.received_qty)}</span>
                </span>
              </div>
            </div>
            <div style="height:24px;" />
          </div>

          <div
            :if={@po.status not in [:confirmed, :received]}
            style="padding:60px 16px;text-align:center;"
          >
            <p style="font-size:14px;color:#6E675A;">
              Pickup available once the supplier has confirmed availability.
            </p>
          </div>
        </div>

        <%!-- add item bottom sheet --%>
        <div
          :if={@live_action == :add_item}
          class="fixed inset-0 z-[60] flex flex-col justify-end"
          role="dialog"
          aria-label="Add item"
        >
          <div
            class="absolute inset-0 bg-black/65"
            phx-click={JS.patch(~p"/manage/purchasing/#{@po.reference}")}
            aria-hidden="true"
          />
          <div
            class="relative w-full bg-[#211E16] mobile-scroll"
            style="border-radius:20px 20px 0 0;border-top:1.5px solid rgba(52,48,37,0.58);max-height:82vh;overflow-y:auto;padding-bottom:max(2rem,env(safe-area-inset-bottom));"
          >
            <div style="padding:12px 16px 10px;border-bottom:1px solid rgba(52,48,37,0.58);position:sticky;top:0;background:#211E16;z-index:1;">
              <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 12px;" />
              <div style="display:flex;align-items:center;justify-content:space-between;">
                <span style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                  Add item
                </span>
                <.link patch={~p"/manage/purchasing/#{@po.reference}"}>
                  <button
                    type="button"
                    ontouchstart=""
                    style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  >
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                      <path
                        d="M18 6L6 18M6 6l12 12"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                      />
                    </svg>
                  </button>
                </.link>
              </div>
            </div>
            <div style="padding:20px 16px;">
              <.live_component
                module={OpenSauceWeb.PurchasingLive.PurchaseOrderItemFormComponent}
                id="po-item-form"
                current_member={@current_member}
                materials={@materials}
                supplier={@po.supplier}
                po_id={@po.id}
                purchase_order_item={nil}
                patch={~p"/manage/purchasing/#{@po.reference}"}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member

    materials = Inventory.list_materials!(actor: member, tenant: member.organisation_id)

    # Load org with address for print sheet
    organisation =
      if Map.get(socket.assigns, :organisation) do
        Accounts.get_organisation!(
          member.organisation_id,
          authorize?: false,
          load: [:address]
        )
      else
        Accounts.get_organisation!(member.organisation_id, authorize?: false, load: [:address])
      end

    {:ok, assign(socket, materials: materials, organisation: organisation)}
  end

  @impl true
  def handle_params(%{"po_ref" => ref}, _uri, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id, load: po_load()]

    case Inventory.get_purchase_order_by_reference(ref, opts) do
      {:ok, nil} ->
        {:noreply,
         socket
         |> put_flash(:error, "Purchase order not found")
         |> push_navigate(to: ~p"/manage/purchasing")}

      {:ok, po} ->
        {:noreply,
         socket
         |> assign(:po, po)
         |> assign(:page_title, po_supplier_name(po))
         |> assign(:main_bg, "bg-[#16140E]")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to load purchase order")
         |> push_navigate(to: ~p"/manage/purchasing")}
    end
  end

  @impl true
  def handle_event("mark_ordered", _params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    case Inventory.mark_purchase_order_ordered(socket.assigns.po, opts) do
      {:ok, _} -> {:noreply, reload_po(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_items", %{"confirm" => confirmations}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    for item <- socket.assigns.po.items do
      qty = parse_decimal(Map.get(confirmations, item.id))
      Inventory.confirm_purchase_order_item(item, %{confirmed_qty: qty}, opts)
    end

    case Inventory.confirm_purchase_order(socket.assigns.po, opts) do
      {:ok, _} -> {:noreply, reload_po(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("finalize_pickup", %{"lineup" => received_qtys}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    for item <- socket.assigns.po.items do
      qty = parse_decimal(Map.get(received_qtys, item.id))
      Inventory.receive_purchase_order_item(item, %{received_qty: qty}, opts)
    end

    case Receiving.receive_po(socket.assigns.po.id, actor: member, tenant: member.organisation_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pickup done. Stock updated.")
         |> push_navigate(to: ~p"/manage/purchasing")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    {:noreply, reload_po(socket)}
  end

  defp reload_po(socket) do
    member = socket.assigns.current_member

    po =
      Inventory.get_purchase_order_by_reference!(
        socket.assigns.po.reference,
        actor: member,
        tenant: member.organisation_id,
        load: po_load()
      )

    assign(socket, :po, po)
  end

  defp po_load do
    [supplier: [:addresses], items: [:material, supplier_catalog_item: [], job: [:address]]]
  end

  defp po_supplier_name(%{supplier: %{name: name}}), do: name
  defp po_supplier_name(_), do: "Unassigned"

  defp plant_label(%{supplier_catalog_item: %{latin_name: ln, cultivar: cv}}) when not is_nil(ln) do
    [ln, cv] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp plant_label(%{material: %{name: name}}) when not is_nil(name), do: name
  defp plant_label(%{supplier_sku: sku}), do: sku

  defp fmt_qty(nil), do: "—"
  defp fmt_qty(%D{} = d), do: D.to_string(d)
  defp fmt_qty(n), do: to_string(n)

  defp parse_decimal(nil), do: D.new(0)
  defp parse_decimal(""), do: D.new(0)

  defp parse_decimal(s) when is_binary(s) do
    case D.parse(s) do
      {d, ""} -> d
      _ -> D.new(0)
    end
  end

  defp fmt_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d")
  defp fmt_date(_), do: "—"

  defp status_label(:draft), do: "draft"
  defp status_label(:ordered), do: "ordered"
  defp status_label(:confirmed), do: "confirmed"
  defp status_label(:received), do: "received"
  defp status_label(s), do: to_string(s)

  defp addr_short(%{name: name, street: street, city: city})
       when not is_nil(name) and name != "" do
    location = [street, city] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(", ")
    if location != "", do: "#{name} · #{location}", else: name
  end

  defp addr_short(%{street: street, city: city}) do
    [street, city] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(", ")
  end

  defp status_badge_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:ordered), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:confirmed), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_badge_style(:received), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(_), do: "background:rgba(110,103,90,0.2);color:#9A9384;"
end
