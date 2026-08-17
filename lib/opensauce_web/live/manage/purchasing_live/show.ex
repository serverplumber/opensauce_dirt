defmodule OpenSauceWeb.PurchasingLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import Ash.Query
  import OpenSauceWeb.Components.Materials
  import OpenSauceWeb.PurchaseOrderPrint

  alias Decimal, as: D
  alias OpenSauce.Accounts
  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauce.Inventory.Receiving

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- print-only sheet (hidden on mobile) --%>
      <div class="hidden print:block">
        <.purchase_order_print
          :if={@print_mode != nil}
          po={@po}
          currency={@organisation.currency}
          organisation={@organisation}
          org_address={@org_address}
          rep={member_name(@current_user)}
          mode={@print_mode}
        />
      </div>

      <div class="print:hidden">
        <%!--
          Search-to-add pattern (canonical for this app):
          A search icon sits in the header bar. Tapping it collapses the entire
          header and replaces it with a full-width search input that auto-focuses.
          Results render inline below, replacing the normal content. The × button
          (always visible, no query needed) collapses back to the header.
          Successfully adding an item also collapses. The normal content — items
          list, sticky CTA — is hidden while search is open.

          State: @search_open boolean (open/closed), @search_query / @search_results
          for the live search. Events: open_search / clear_search / search.

          Do not use a persistent search bar, a bottom sheet form, or a separate
          search screen. This header-collapse pattern is the standard for any
          screen where items are added from a catalogue or lookup.
        --%>
        <%!-- top bar: normal header --%>
        <div
          :if={!@search_open}
          style="padding:12px 16px 10px;display:flex;align-items:center;gap:10px;"
        >
          <.link navigate={~p"/manage/purchasing"}>
            <button
              type="button"
              ontouchstart=""
              style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                <path
                  d="M15 18l-6-6 6-6"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                />
              </svg>
            </button>
          </.link>
          <div style="flex:1;min-width:0;">
            <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:19px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
              {po_supplier_name(@po)}
            </h1>
            <span style={"margin-top:3px;display:inline-block;#{status_badge_style(@po.status)}border-radius:20px;padding:2px 9px;font-size:11px;font-weight:700;"}>
              {status_label(@po.status)}
            </span>
          </div>
          <button
            :if={@po.status == :draft}
            type="button"
            phx-click="open_search"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;flex-shrink:0;"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="2" />
              <path
                d="M21 21l-4.35-4.35"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
            </svg>
          </button>
          <button
            :if={@po.status in [:draft, :ordered]}
            type="button"
            phx-click="open_print_modal"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;flex-shrink:0;"
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

        <%!-- top bar: search active — full-width input replaces header --%>
        <div :if={@search_open} style="padding:12px 16px 10px;">
          <form phx-change="search" style="position:relative;">
            <svg
              width="15"
              height="15"
              viewBox="0 0 24 24"
              fill="none"
              style="position:absolute;left:12px;top:50%;transform:translateY(-50%);color:#6E675A;pointer-events:none;"
            >
              <circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="2" />
              <path
                d="M21 21l-4.35-4.35"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
            </svg>
            <input
              class="dark-input"
              type="text"
              name="q"
              value={@search_query}
              phx-debounce="300"
              autocomplete="off"
              placeholder="Search catalogue to add…"
              phx-mounted={JS.focus()}
              style="padding-left:36px;padding-right:52px;"
            />
            <button
              type="button"
              phx-click="clear_search"
              ontouchstart=""
              style="position:absolute;right:10px;top:50%;transform:translateY(-50%);background:none;border:none;color:#DB9258;cursor:pointer;padding:4px;line-height:0;"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path
                  d="M18 6L6 18M6 6l12 12"
                  stroke="currentColor"
                  stroke-width="2.5"
                  stroke-linecap="round"
                />
              </svg>
            </button>
          </form>
        </div>

        <%!-- PO detail view: show / items / add_item --%>
        <div :if={@live_action in [:show, :items, :add_item]}>
          <%!-- catalog search results --%>
          <div
            :if={@search_query != ""}
            style="padding:0 16px;display:flex;flex-direction:column;gap:6px;padding-bottom:100px;"
          >
            <div
              :if={@search_results == []}
              style="font-size:13px;color:#6E675A;text-align:center;padding:20px 0;"
            >
              No results for "{@search_query}"
            </div>
            <div
              :for={sci <- @search_results}
              style="background:#211E16;border-radius:12px;padding:12px;border:1px solid rgba(52,48,37,0.58);"
            >
              <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
                <div style="min-width:0;flex:1;">
                  <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {sci_title(sci)}
                  </p>
                  <p style="font-size:11px;color:#6E675A;margin-top:2px;">
                    {sci.supplier_catalog.supplier.name}
                    {if sci.format_description, do: " · #{sci.format_description}"}
                    {if sci.sku, do: " · #{sci.sku}"}
                  </p>
                  <p :if={sci.unit_price} style="font-size:11px;color:#DB9258;margin-top:2px;">
                    {format_currency(@organisation.currency, sci.unit_price)}/unit
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="add_catalog_item"
                  phx-value-id={sci.id}
                  ontouchstart=""
                  style="flex-shrink:0;background:rgba(84,181,126,0.12);border:1px solid rgba(84,181,126,0.3);border-radius:8px;padding:6px 12px;cursor:pointer;color:#54B57E;font-size:13px;font-weight:700;"
                >
                  + Add
                </button>
              </div>
            </div>
          </div>

          <%!-- ordered / confirmed date chips --%>
          <div
            :if={(@po.ordered_at || @po.received_at) && @search_query == ""}
            style="padding:0 16px 12px;display:flex;gap:8px;"
          >
            <span
              :if={@po.ordered_at}
              style="background:rgba(52,48,37,0.5);border-radius:20px;padding:3px 10px;font-size:11px;color:#9A9384;"
            >
              sent {fmt_date(@po.ordered_at)}
            </span>
            <span
              :if={@po.received_at}
              style="background:rgba(52,48,37,0.5);border-radius:20px;padding:3px 10px;font-size:11px;color:#9A9384;"
            >
              received {fmt_date(@po.received_at)}
            </span>
          </div>

          <%!-- ordered: inline confirmation form --%>
          <div :if={@po.status == :ordered} style="padding:0 16px 10px;">
            <p style="font-size:13px;color:#9A9384;margin-bottom:12px;">
              Enter the quantity the supplier confirmed they have set aside.
            </p>
            <form
              phx-submit="confirm_items"
              id="confirm-form"
              style="display:flex;flex-direction:column;gap:8px;"
            >
              <div
                :for={item <- @po.items}
                style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;"
              >
                <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
                  <div style="min-width:0;flex:1;">
                    <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;">
                      {plant_label(item)}
                    </p>
                    <p style="font-size:11.5px;font-family:monospace;color:#6E675A;margin-top:2px;">
                      {item.supplier_sku}
                    </p>
                  </div>
                  <span
                    :if={item.is_reservation}
                    style="flex-shrink:0;background:rgba(90,180,216,0.15);color:#5AB4D8;border-radius:12px;padding:2px 8px;font-size:10px;font-weight:700;"
                  >
                    cherry-pick
                  </span>
                </div>
                <div style="display:flex;align-items:center;justify-content:space-between;margin-top:10px;">
                  <span style="font-size:12px;color:#9A9384;">
                    ordered:
                    <span style="color:#F4EFE2;font-weight:600;">{fmt_qty(item.quantity)}</span>
                  </span>
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

          <%!-- items list (non-ordered states, not searching) --%>
          <div :if={@po.status != :ordered && @search_query == ""} style="padding:0 16px;">
            <p
              :if={@po.items == []}
              style="font-size:13.5px;color:#6E675A;text-align:center;padding:32px 0;"
            >
              No items yet
            </p>
            <div style="display:flex;flex-direction:column;gap:16px;">
              <div :for={{garden, items} <- garden_groups(@po.items)}>
                <%!-- garden HR header (only when a garden is known) --%>
                <div
                  :if={garden != nil}
                  phx-click="set_garden_context"
                  phx-value-garden_id={garden.id}
                  ontouchstart=""
                  style="display:flex;align-items:center;gap:8px;margin-bottom:8px;cursor:pointer;"
                >
                  <span style={"font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;white-space:nowrap;#{if @selected_garden_id == garden.id, do: "color:#54B57E;", else: "color:#6E675A;"}"}>
                    {garden_group_label(garden)}
                  </span>
                  <div style={"flex:1;height:1px;#{if @selected_garden_id == garden.id, do: "background:rgba(84,181,126,0.35);", else: "background:rgba(52,48,37,0.58);"}"}>
                  </div>
                  <svg
                    :if={@selected_garden_id == garden.id}
                    width="12"
                    height="12"
                    viewBox="0 0 24 24"
                    fill="none"
                    style="flex-shrink:0;color:#54B57E;"
                  >
                    <path
                      d="M20 6L9 17l-5-5"
                      stroke="currentColor"
                      stroke-width="2.5"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                </div>
                <%!-- items in this group --%>
                <div style="display:flex;flex-direction:column;gap:8px;">
                  <.material_line
                    :for={item <- items}
                    jm={display_item(item, @po.status)}
                    currency={@organisation.currency}
                    show_supplier={false}
                    job={nil}
                    removable={@po.status == :draft}
                    on_tap={
                      if @po.status in [:draft, :confirmed],
                        do: JS.push("open_material_sheet", value: %{id: item.id}),
                        else: %JS{}
                    }
                    on_remove={JS.push("remove_po_item", value: %{id: item.id})}
                  />
                </div>
              </div>
            </div>
          </div>

          <%!-- dashed + button for manual items (draft only, not searching) --%>
          <div :if={@po.status == :draft && @search_query == ""} style="padding:10px 16px 0;">
            <button
              type="button"
              phx-click="start_add_manual_item"
              ontouchstart=""
              style="width:100%;border-radius:12px;border:1.5px dashed rgba(84,181,126,0.3);padding:10px;background:none;cursor:pointer;display:flex;align-items:center;justify-content:center;color:#54B57E;"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path
                  d="M12 5v14M5 12h14"
                  stroke="currentColor"
                  stroke-width="2.2"
                  stroke-linecap="round"
                />
              </svg>
            </button>
          </div>

          <%!-- spacer for sticky CTA --%>
          <div :if={@po.status != :ordered && @search_query == ""} style="height:110px;" />

          <%!-- sticky CTA --%>
          <div
            :if={@po.status in [:draft, :confirmed] && @search_query == ""}
            style="position:fixed;bottom:74px;left:0;right:0;padding:12px 16px;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);"
          >
            <button
              :if={@po.status == :draft}
              type="button"
              phx-click="mark_ordered"
              ontouchstart=""
              style="width:100%;height:50px;background:#54B57E;border:none;border-radius:14px;font-size:15px;font-weight:700;color:#0C1F15;cursor:pointer;"
            >
              Send order →
            </button>
            <.link
              :if={@po.status == :confirmed}
              navigate={~p"/manage/purchasing/#{@po.reference}/lineup"}
            >
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
          <div
            :if={@po.status == :confirmed}
            style="padding:0 16px;display:flex;flex-direction:column;gap:10px;"
          >
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
              collect — confirm qty and cost
            </p>

            <form
              phx-submit="finalize_pickup"
              id="lineup-form"
              style="display:flex;flex-direction:column;gap:8px;"
            >
              <div
                :for={item <- @po.items}
                style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;"
              >
                <%!-- name + cherry-pick chip --%>
                <div style="display:flex;align-items:baseline;gap:8px;margin-bottom:8px;">
                  <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {plant_label(item)}
                  </p>
                  <span
                    :if={item.is_reservation}
                    style="background:rgba(90,180,216,0.15);color:#5AB4D8;border-radius:12px;padding:1px 7px;font-size:10px;font-weight:700;flex-shrink:0;"
                  >
                    cherry-pick
                  </span>
                </div>
                <%!-- job/garden attribution --%>
                <div
                  :if={item.job && item.job.garden}
                  style="display:flex;align-items:center;gap:5px;margin-bottom:8px;"
                >
                  <svg
                    width="10"
                    height="10"
                    viewBox="0 0 24 24"
                    fill="none"
                    style="color:#6E675A;flex-shrink:0;"
                  >
                    <path
                      d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linejoin="round"
                    />
                    <circle cx="12" cy="9" r="2.5" stroke="currentColor" stroke-width="2" />
                  </svg>
                  <span style="font-size:11px;color:#6E675A;">{job_location_label(item.job)}</span>
                </div>
                <%!-- qty + cost inputs --%>
                <div style="display:flex;gap:8px;align-items:flex-end;">
                  <div style="flex:1;">
                    <p style="font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:4px;">
                      Taking
                      <span style="font-weight:400;text-transform:none;letter-spacing:0;color:#4A4438;">
                        (of {fmt_qty(item.confirmed_qty || item.quantity)})
                      </span>
                    </p>
                    <input
                      type="number"
                      name={"lineup[#{item.id}]"}
                      value={fmt_qty(item.confirmed_qty || item.quantity)}
                      step="1"
                      min="0"
                      inputmode="numeric"
                      style="width:100%;background:#16140E;border:1px solid rgba(52,48,37,0.8);border-radius:8px;padding:8px 10px;font-size:15px;font-weight:700;color:#F4EFE2;text-align:center;"
                    />
                  </div>
                  <div style="flex:1;">
                    <p style="font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#9A7344;margin-bottom:4px;">
                      Unit cost
                    </p>
                    <input
                      type="number"
                      name={"cost[#{item.id}]"}
                      value={item.cost}
                      step="0.01"
                      min="0"
                      inputmode="decimal"
                      placeholder="—"
                      style="width:100%;background:#16140E;border:1px solid rgba(52,48,37,0.8);border-radius:8px;padding:8px 10px;font-size:15px;font-weight:700;color:#DB9258;text-align:center;"
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

          <%!-- received summary --%>
          <div
            :if={@po.status == :received}
            style="padding:0 16px;display:flex;flex-direction:column;gap:8px;"
          >
            <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-top:4px;">
              received
            </p>
            <div
              :for={item <- @po.items}
              phx-click="open_received_sheet"
              phx-value-id={item.id}
              ontouchstart=""
              style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:14px;padding:12px 14px;cursor:pointer;"
            >
              <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
                <div style="flex:1;min-width:0;">
                  <p style="font-size:14px;font-weight:700;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {plant_label(item)}
                  </p>
                  <div
                    :if={item.job && item.job.garden}
                    style="display:flex;align-items:center;gap:5px;margin-top:3px;"
                  >
                    <svg
                      width="10"
                      height="10"
                      viewBox="0 0 24 24"
                      fill="none"
                      style="color:#6E675A;flex-shrink:0;"
                    >
                      <path
                        d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linejoin="round"
                      />
                      <circle cx="12" cy="9" r="2.5" stroke="currentColor" stroke-width="2" />
                    </svg>
                    <span style="font-size:11px;color:#6E675A;">{job_location_label(item.job)}</span>
                  </div>
                  <div style="display:flex;gap:10px;margin-top:5px;">
                    <span style="font-size:12px;color:#9A9384;">
                      ordered
                      <span style="color:#F4EFE2;font-weight:600;">
                        {fmt_qty(item.confirmed_qty || item.quantity)}
                      </span>
                    </span>
                    <span style="font-size:12px;color:#9A9384;">
                      received
                      <span style="color:#54B57E;font-weight:600;">{fmt_qty(item.received_qty)}</span>
                    </span>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:10px;flex-shrink:0;">
                  <div :if={item.cost} style="text-align:right;">
                    <p style="font-size:13px;font-weight:700;color:#DB9258;">
                      {format_money(@organisation.currency, item.cost)}
                      <span style="font-size:10px;font-weight:400;color:#9A7344;">/ unit</span>
                    </p>
                    <p :if={item.received_qty} style="font-size:11px;color:#6E675A;margin-top:2px;">
                      = {format_money(@organisation.currency, D.mult(item.received_qty, item.cost))}
                    </p>
                  </div>
                  <svg
                    width="14"
                    height="14"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                    style="color:#6E675A;flex-shrink:0;"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                    />
                  </svg>
                </div>
              </div>
            </div>
            <%!-- total --%>
            <div style="display:flex;justify-content:flex-end;padding:8px 4px;border-top:1px solid rgba(52,48,37,0.45);margin-top:4px;">
              <span style="font-size:13px;color:#9A9384;">
                Total paid:
                <span style="font-size:15px;font-weight:700;color:#DB9258;margin-left:6px;">
                  {format_money(@organisation.currency, received_total(@po.items))}
                </span>
              </span>
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

        <%!-- manual add bottom sheet --%>
        <div
          :if={@adding_manual_item}
          style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
        >
          <div
            phx-click="cancel_add_manual_item"
            style="position:absolute;inset:0;background:rgba(0,0,0,0.65);"
          />
          <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:0 0 40px;">
            <div style="padding:12px 16px 14px;border-bottom:1px solid rgba(52,48,37,0.58);">
              <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 14px;" />
              <div style="display:flex;align-items:center;justify-content:space-between;">
                <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                  Add item
                </p>
                <button
                  type="button"
                  phx-click="cancel_add_manual_item"
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
              </div>
            </div>
            <form
              phx-submit="save_manual_item"
              style="padding:16px;display:flex;flex-direction:column;gap:12px;"
            >
              <div>
                <label class="dark-label">Description</label>
                <input
                  class="dark-input"
                  type="text"
                  name="description"
                  placeholder="e.g. 10 white geum"
                  phx-mounted={JS.focus()}
                  style="width:100%;"
                />
              </div>
              <div style="display:flex;gap:10px;">
                <div style="flex:1;">
                  <label class="dark-label">Qty</label>
                  <input
                    class="dark-input"
                    type="number"
                    name="qty"
                    value="1"
                    min="1"
                    step="1"
                    inputmode="numeric"
                    style="width:100%;"
                  />
                </div>
                <div style="flex:1;">
                  <label class="dark-label" style="color:#9A7344;">Cost</label>
                  <input
                    class="dark-input"
                    type="number"
                    name="cost"
                    min="0"
                    step="0.01"
                    inputmode="decimal"
                    placeholder="—"
                    style="width:100%;color:#DB9258;"
                  />
                </div>
              </div>
              <button
                type="button"
                phx-click="toggle_manual_reservation"
                ontouchstart=""
                style="display:flex;align-items:center;justify-content:space-between;width:100%;background:none;border:none;padding:0;cursor:pointer;"
              >
                <span style="font-size:13px;color:#9A9384;">Cherry-pick</span>
                <div style={"width:40px;height:24px;border-radius:999px;flex-shrink:0;transition:background 0.15s;position:relative;#{if @manual_is_reservation, do: "background:#54B57E;", else: "background:#3A3528;"}"}>
                  <div style={"width:18px;height:18px;border-radius:999px;background:#fff;position:absolute;top:3px;transition:left 0.15s;#{if @manual_is_reservation, do: "left:19px;", else: "left:3px;"}"}>
                  </div>
                </div>
              </button>

              <div style="margin-top:4px;">
                <.glow_button type="submit" valid={true}>Add</.glow_button>
              </div>
            </form>
          </div>
        </div>

        <%!-- received item correction sheet --%>
        <div
          :if={@editing_received_item != nil}
          style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
        >
          <div
            phx-click="close_received_sheet"
            style="position:absolute;inset:0;background:rgba(0,0,0,0.65);"
          />
          <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:0 0 40px;">
            <div style="padding:12px 16px 14px;border-bottom:1px solid rgba(52,48,37,0.58);">
              <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 14px;" />
              <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
                <div style="min-width:0;flex:1;">
                  <p style="font-size:15px;font-weight:700;font-style:italic;color:#F4EFE2;line-height:1.2;">
                    {plant_label(@editing_received_item)}
                  </p>
                  <p style="font-size:11px;color:#6E675A;margin-top:3px;">
                    Correct received qty or cost
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="close_received_sheet"
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;flex-shrink:0;"
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
              </div>
            </div>
            <form phx-submit="save_received_sheet" style="padding:16px;">
              <div style="display:flex;gap:10px;">
                <div style="flex:1;">
                  <label class="dark-label">Received qty</label>
                  <input
                    class="dark-input"
                    type="number"
                    name="received_qty"
                    value={@editing_received_item.received_qty}
                    min="0"
                    step="1"
                    inputmode="numeric"
                    style="text-align:center;"
                  />
                </div>
                <div style="flex:1;">
                  <label class="dark-label" style="color:#9A7344;">Unit cost</label>
                  <input
                    class="dark-input"
                    type="number"
                    name="cost"
                    value={@editing_received_item.cost}
                    min="0"
                    step="0.01"
                    inputmode="decimal"
                    placeholder="—"
                    style="color:#DB9258;"
                  />
                </div>
              </div>
              <div style="margin-top:16px;">
                <.glow_button type="submit" valid={true}>Save</.glow_button>
              </div>
            </form>
          </div>
        </div>

        <%!-- print picker --%>
        <div
          :if={@print_modal}
          style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
        >
          <div
            phx-click="close_print_modal"
            style="position:absolute;inset:0;background:rgba(0,0,0,0.65);"
          />
          <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:0 0 40px;">
            <div style="padding:12px 16px 16px;border-bottom:1px solid rgba(52,48,37,0.58);">
              <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 14px;" />
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                Print
              </p>
            </div>
            <div style="padding:16px;display:flex;flex-direction:column;gap:10px;">
              <button
                type="button"
                phx-click="select_print"
                phx-value-mode="rollup"
                ontouchstart=""
                style="width:100%;background:#211E16;border:1.5px solid rgba(52,48,37,0.8);border-radius:14px;padding:14px 16px;text-align:left;cursor:pointer;"
              >
                <p style="font-size:14px;font-weight:700;color:#F4EFE2;">Supply run totals</p>
                <p style="font-size:12px;color:#6E675A;margin-top:2px;">
                  One page — quantities rolled up for the supplier
                </p>
              </button>
              <button
                type="button"
                phx-click="select_print"
                phx-value-mode="sheets"
                ontouchstart=""
                style="width:100%;background:#211E16;border:1.5px solid rgba(52,48,37,0.8);border-radius:14px;padding:14px 16px;text-align:left;cursor:pointer;"
              >
                <p style="font-size:14px;font-weight:700;color:#F4EFE2;">Site sheets</p>
                <p style="font-size:12px;color:#6E675A;margin-top:2px;">
                  One sheet per delivery address for the crew
                </p>
              </button>
            </div>
          </div>
        </div>

        <%!-- edit item cost / price / qty --%>
        <.material_line_sheet
          material={@editing_material}
          currency={@organisation.currency}
          on_close={JS.push("close_material_sheet")}
          save_event="save_material_sheet"
        />

        <%!-- add item bottom sheet --%>
        <div
          :if={@live_action == :add_item}
          class="z-[60] fixed inset-0 flex flex-col justify-end"
          role="dialog"
          aria-label="Add item"
        >
          <div
            class="bg-black/65 absolute inset-0"
            phx-click={JS.patch(~p"/manage/purchasing/#{@po.reference}")}
            aria-hidden="true"
          />
          <div
            class="bg-[#211E16] mobile-scroll relative w-full"
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

    materials =
      Inventory.list_materials!(
        actor: member,
        tenant: member.organisation_id
      )

    organisation =
      Accounts.get_organisation!(member.organisation_id, authorize?: false)

    org_address =
      CRM.Address
      |> filter(organisation_id == ^member.organisation_id and is_nil(customer_id))
      |> Ash.read_one!(authorize?: false)

    {:ok,
     assign(socket,
       materials: materials,
       organisation: organisation,
       org_address: org_address,
       editing_material: nil,
       editing_received_item: nil,
       selected_garden_id: nil,
       search_query: "",
       search_results: [],
       search_open: false,
       adding_manual_item: false,
       manual_is_reservation: false,
       print_modal: false,
       print_mode: nil
     )}
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
  def handle_event("start_add_manual_item", _params, socket) do
    {:noreply, assign(socket, adding_manual_item: true, manual_is_reservation: false)}
  end

  @impl true
  def handle_event("cancel_add_manual_item", _params, socket) do
    {:noreply, assign(socket, adding_manual_item: false, manual_is_reservation: false)}
  end

  @impl true
  def handle_event("toggle_manual_reservation", _params, socket) do
    {:noreply, assign(socket, :manual_is_reservation, !socket.assigns.manual_is_reservation)}
  end

  @impl true
  def handle_event("save_manual_item", params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    description = String.trim(params["description"] || "")

    if description == "" do
      {:noreply, socket}
    else
      attrs = %{
        purchase_order_id: socket.assigns.po.id,
        supplier_sku: description,
        quantity: parse_decimal(params["qty"]),
        cost: parse_optional_decimal(params["cost"]),
        is_reservation: socket.assigns.manual_is_reservation
      }

      case Inventory.create_purchase_order_item(attrs, opts) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(
             adding_manual_item: false,
             manual_is_reservation: false,
             manual_sku: "",
             manual_cost: nil
           )
           |> reload_po()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not add item.")}
      end
    end
  end

  @impl true
  def handle_event("open_print_modal", _params, socket) do
    {:noreply, assign(socket, print_modal: true)}
  end

  @impl true
  def handle_event("close_print_modal", _params, socket) do
    {:noreply, assign(socket, print_modal: false)}
  end

  @impl true
  def handle_event("select_print", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(print_modal: false, print_mode: String.to_existing_atom(mode))
     |> push_event("print", %{})}
  end

  @impl true
  def handle_event("open_search", _params, socket) do
    {:noreply, assign(socket, :search_open, true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    query = String.trim(query)
    member = socket.assigns.current_member

    results =
      if String.length(query) >= 2 do
        Inventory.search_supplier_catalog_items!(query,
          actor: member,
          tenant: member.organisation_id,
          load: [supplier_catalog: [:supplier]]
        )
      else
        []
      end

    {:noreply, socket |> assign(:search_query, query) |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_open, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def handle_event("add_catalog_item", %{"id" => sci_id}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    sci =
      Inventory.get_supplier_catalog_item_by_id!(sci_id,
        actor: member,
        tenant: member.organisation_id,
        load: [supplier_catalog: [:supplier]]
      )

    attrs = %{
      purchase_order_id: socket.assigns.po.id,
      supplier_catalog_item_id: sci.id,
      supplier_sku: sci.sku || sci_title(sci),
      cost: sci.unit_price,
      material_id: sci.material_id,
      quantity: 1
    }

    case Inventory.create_purchase_order_item(attrs, opts) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:search_open, false)
         |> assign(:search_query, "")
         |> assign(:search_results, [])
         |> reload_po()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add item.")}
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
  def handle_event("finalize_pickup", params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]
    received_qtys = Map.get(params, "lineup", %{})
    costs = Map.get(params, "cost", %{})

    for item <- socket.assigns.po.items do
      attrs = %{
        received_qty: parse_decimal(Map.get(received_qtys, item.id)),
        cost: parse_optional_decimal(Map.get(costs, item.id))
      }

      Inventory.receive_purchase_order_item(item, attrs, opts)
    end

    case Receiving.receive_po(socket.assigns.po.id, actor: member, tenant: member.organisation_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pickup done. Stock updated.")
         |> push_navigate(to: ~p"/manage/purchasing", replace: true)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_material_sheet", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.po.items, &(&1.id == id))
    {:noreply, assign(socket, :editing_material, item)}
  end

  @impl true
  def handle_event("close_material_sheet", _params, socket) do
    {:noreply, assign(socket, :editing_material, nil)}
  end

  @impl true
  def handle_event("save_material_sheet", params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    attrs = %{
      quantity: parse_decimal(params["nb"]),
      cost: parse_optional_decimal(params["cost"]),
      price: parse_optional_decimal(params["price"])
    }

    case Inventory.update_purchase_order_item(socket.assigns.editing_material, attrs, opts) do
      {:ok, _} -> {:noreply, socket |> assign(:editing_material, nil) |> reload_po()}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not save.")}
    end
  end

  @impl true
  def handle_event("open_received_sheet", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.po.items, &(&1.id == id))
    {:noreply, assign(socket, :editing_received_item, item)}
  end

  @impl true
  def handle_event("close_received_sheet", _params, socket) do
    {:noreply, assign(socket, :editing_received_item, nil)}
  end

  @impl true
  def handle_event("save_received_sheet", params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    attrs = %{
      received_qty: parse_optional_decimal(params["received_qty"]),
      cost: parse_optional_decimal(params["cost"])
    }

    case Inventory.receive_purchase_order_item(socket.assigns.editing_received_item, attrs, opts) do
      {:ok, _} -> {:noreply, socket |> assign(:editing_received_item, nil) |> reload_po()}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not save.")}
    end
  end

  @impl true
  def handle_event("remove_po_item", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    with true <- socket.assigns.po.status == :draft,
         item when not is_nil(item) <- Enum.find(socket.assigns.po.items, &(&1.id == id)),
         :ok <- Inventory.destroy_purchase_order_item(item, opts) do
      {:noreply, reload_po(socket)}
    else
      _ -> {:noreply, socket}
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
    [
      supplier: [:addresses],
      items: [
        :material,
        supplier_catalog_item: [supplier_catalog: [:supplier]],
        job: [garden: [:customer], engagement: []]
      ]
    ]
  end

  # Pass the most relevant quantity for the PO state to material_line.
  defp display_item(item, :confirmed), do: %{item | quantity: item.confirmed_qty || item.quantity}

  defp display_item(item, :received), do: %{item | quantity: item.received_qty || item.confirmed_qty || item.quantity}

  defp display_item(item, _), do: item

  defp parse_optional_decimal(nil), do: nil
  defp parse_optional_decimal(""), do: nil
  defp parse_optional_decimal(s), do: D.new(s)

  defp po_supplier_name(%{supplier: %{name: name}}), do: name
  defp po_supplier_name(_), do: "Unassigned"

  defp member_name(%{first_name: fn_, last_name: ln}) when not is_nil(fn_) or not is_nil(ln),
    do: [fn_, ln] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

  defp member_name(_), do: nil

  defp sci_title(%{latin_name: ln, cultivar: cv}) when not is_nil(ln) do
    [ln, cv] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp sci_title(%{name: name}) when not is_nil(name), do: name
  defp sci_title(%{sku: sku}) when not is_nil(sku), do: sku
  defp sci_title(_), do: "—"

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

  defp addr_short(%{name: name, street: street, city: city}) when not is_nil(name) and name != "" do
    location = [street, city] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(", ")
    if location == "", do: name, else: "#{name} · #{location}"
  end

  defp addr_short(%{street: street, city: city}) do
    [street, city] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(", ")
  end

  defp status_badge_style(:draft), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:ordered), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp status_badge_style(:confirmed), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp status_badge_style(:received), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp status_badge_style(_), do: "background:rgba(110,103,90,0.2);color:#9A9384;"

  def handle_event("set_garden_context", %{"garden_id" => id}, socket) do
    current = socket.assigns.selected_garden_id
    {:noreply, assign(socket, :selected_garden_id, if(current == id, do: nil, else: id))}
  end

  defp garden_groups(items) do
    with_garden = Enum.filter(items, fn item -> item.job && item.job.garden_id end)

    if with_garden == [] do
      [{nil, items}]
    else
      items
      |> Enum.group_by(fn item -> item.job && item.job.garden_id end)
      |> Enum.map(fn {_id, group} ->
        garden = Enum.find_value(group, fn item -> item.job && item.job.garden end)
        {garden, group}
      end)
      |> Enum.sort_by(fn {garden, _} -> garden_sort_key(garden) end)
    end
  end

  defp garden_sort_key(nil), do: ""
  defp garden_sort_key(%{name: name}) when not is_nil(name), do: name

  defp garden_sort_key(%{city: city, street: street}) when not is_nil(city), do: "#{city}#{street}"

  defp garden_sort_key(_), do: ""

  defp garden_group_label(%{customer: customer, name: garden_name}) when not is_nil(customer) do
    client = garden_customer_short(customer)
    if garden_name, do: "#{client} — #{garden_name}", else: client
  end

  defp garden_group_label(%{name: name}) when not is_nil(name), do: name
  defp garden_group_label(%{street: street}) when not is_nil(street), do: street
  defp garden_group_label(_), do: "—"

  defp job_location_label(%{garden: %{customer: customer, name: garden_name}}) when not is_nil(customer) do
    client = garden_customer_short(customer)
    if garden_name, do: "#{client} — #{garden_name}", else: client
  end

  defp job_location_label(%{garden: %{name: name}}) when not is_nil(name), do: name
  defp job_location_label(%{garden: garden}), do: garden.street || "—"
  defp job_location_label(_), do: "—"

  defp garden_customer_short(%{company_name_nickname: cn}) when not is_nil(cn), do: cn

  defp garden_customer_short(%{first_name: fn_, last_name: ln}), do: [fn_, ln] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

  defp garden_customer_short(_), do: "—"

  defp received_total(items) do
    Enum.reduce(items, D.new(0), fn item, acc ->
      qty = item.received_qty || D.new(0)
      cost = item.cost || D.new(0)
      D.add(acc, D.mult(qty, cost))
    end)
  end
end
