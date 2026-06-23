# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.Components.Materials do
  @moduledoc false
  use Phoenix.Component

  import OpenSauceWeb.HtmlHelpers
  import OpenSauceWeb.Components.Core, only: [glow_button: 1]

  alias Phoenix.LiveView.JS

  # ---------------------------------------------------------------------------
  # material_search_header
  #
  # Combines a nav row (back + title + done) with a search input.
  # While the user is typing, the nav row hides and a × button appears inside
  # the input to clear the query and restore the nav. The clear button fires
  # clear_event (default "clear_search") which the parent LiveView handles.
  #
  # Usage:
  #   <.material_search_header search_query={@search_query} placeholder="…">
  #     <:nav>
  #       … back link, title, done link …
  #     </:nav>
  #   </.material_search_header>
  #
  # Parent must handle:
  #   "search"       → %{"q" => query}  (phx-change, already debounced)
  #   "clear_search" → reset query + results + filters
  # ---------------------------------------------------------------------------

  attr :search_query, :string, required: true
  attr :placeholder, :string, default: "Search…"
  attr :search_event, :string, default: "search"
  attr :clear_event, :string, default: "clear_search"
  slot :nav, required: true

  def material_search_header(assigns) do
    ~H"""
    <div style="padding:12px 16px 0;">
      <div
        :if={@search_query == ""}
        style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;"
      >
        {render_slot(@nav)}
      </div>
      <form phx-change={@search_event} style="position:relative;">
        <svg
          width="15" height="15" viewBox="0 0 24 24" fill="none"
          style="position:absolute;left:12px;top:50%;transform:translateY(-50%);color:#6E675A;pointer-events:none;"
        >
          <circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="2"/>
          <path d="M21 21l-4.35-4.35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
        </svg>
        <input
          class="dark-input"
          type="text"
          name="q"
          value={@search_query}
          phx-debounce="300"
          autocomplete="off"
          placeholder={@placeholder}
          style={"padding-left:36px;#{if @search_query != "", do: "padding-right:36px;", else: ""}"}
        />
        <button
          :if={@search_query != ""}
          type="button"
          phx-click={@clear_event}
          ontouchstart=""
          style="position:absolute;right:10px;top:50%;transform:translateY(-50%);background:none;border:none;color:#DB9258;cursor:pointer;padding:4px;line-height:0;"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
          </svg>
        </button>
      </form>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # material_line
  #
  # Read surface for a single material line item (job or engagement).
  # Displays ×qty · latin name/cultivar · cost (amber) · price (green) · remove.
  # Tapping the card fires on_tap; tapping × fires on_remove without bubbling.
  # ---------------------------------------------------------------------------

  attr :jm, :map, required: true
  attr :currency, :atom, required: true
  attr :from_plan, :boolean, default: false
  attr :removable, :boolean, default: true
  attr :on_tap, JS, default: %JS{}
  attr :on_remove, JS, default: %JS{}

  def material_line(assigns) do
    ~H"""
    <div
      phx-click={@on_tap}
      ontouchstart=""
      style={"background:#211E16;border-radius:12px;padding:10px 12px;border:1px solid #{if @from_plan, do: "#54B57E", else: "rgba(52,48,37,0.58)"};cursor:pointer;"}
    >
      <div style="display:flex;align-items:center;gap:10px;">
        <div style="flex-shrink:0;min-width:32px;text-align:center;">
          <span style="font-size:11px;font-weight:700;color:#6E675A;">×</span><span style="font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.02em;">{@jm.quantity}</span>
        </div>
        <div style="flex:1;min-width:0;">
          <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {catalog_item_title(@jm.supplier_catalog_item)}
          </p>
          <p style="font-size:11px;color:#9A9384;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {@jm.supplier_catalog_item.supplier_catalog.supplier.name}
            {if @jm.supplier_catalog_item.format_description,
              do: " · #{@jm.supplier_catalog_item.format_description}"}
            {if @from_plan, do: " · plan"}
          </p>
        </div>
        <div style="display:flex;align-items:center;gap:8px;flex-shrink:0;">
          <div style="text-align:right;">
            <p style="font-size:12px;font-weight:700;color:#DB9258;line-height:1.2;">
              {if @jm.cost, do: format_currency(@currency, @jm.cost), else: "—"}
            </p>
            <p style="font-size:10px;color:#9A7344;margin-top:1px;">cost</p>
          </div>
          <div style="text-align:right;">
            <p style="font-size:12px;font-weight:700;color:#54B57E;line-height:1.2;">
              {if @jm.price, do: format_currency(@currency, @jm.price), else: "—"}
            </p>
            <p style="font-size:10px;color:#3A7A57;margin-top:1px;">price</p>
          </div>
          <button
            :if={@removable}
            type="button"
            phx-click={@on_remove}
            ontouchstart=""
            style="background:none;border:none;color:#6E675A;cursor:pointer;padding:4px;line-height:0;"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none">
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
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # material_line_sheet
  #
  # Edit surface for a single material line item. Renders as a bottom sheet
  # overlay. Pass material=nil to hide. The sheet owns no state — the parent
  # LiveView holds editing_material and handles save_event / on_close.
  # ---------------------------------------------------------------------------

  attr :material, :map, default: nil
  attr :currency, :atom, required: true
  attr :on_close, JS, default: %JS{}
  attr :save_event, :string, default: "save_material_sheet"
  attr :show_date, :boolean, default: false

  def material_line_sheet(assigns) do
    ~H"""
    <div
      :if={@material != nil}
      style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
    >
      <div phx-click={@on_close} style="position:absolute;inset:0;background:rgba(0,0,0,0.65);">
      </div>
      <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:0 0 40px;">
        <div style="padding:12px 16px 14px;border-bottom:1px solid rgba(52,48,37,0.58);">
          <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 14px;">
          </div>
          <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
            <div style="min-width:0;flex:1;">
              <p style="font-size:15px;font-weight:700;color:#F4EFE2;line-height:1.2;">
                {catalog_item_title(@material.supplier_catalog_item)}
              </p>
              <p style="font-size:11px;color:#6E675A;margin-top:3px;">
                {@material.supplier_catalog_item.supplier_catalog.supplier.name}
              </p>
            </div>
            <button
              type="button"
              phx-click={@on_close}
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
        <form phx-submit={@save_event} style="padding:16px;">
          <div style="display:flex;gap:10px;">
            <div style="flex:1;">
              <label class="dark-label">Qty</label>
              <input
                class="dark-input"
                type="number"
                name="nb"
                value={@material.quantity}
                min="0"
                step="1"
                inputmode="numeric"
                style="text-align:center;"
              />
            </div>
            <div style="flex:1;">
              <label class="dark-label" style="color:#9A7344;">Cost</label>
              <input
                class="dark-input"
                type="number"
                name="cost"
                value={@material.cost}
                min="0"
                step="0.01"
                inputmode="decimal"
                placeholder="—"
                style="color:#DB9258;"
              />
            </div>
            <div style="flex:1;">
              <label class="dark-label" style="color:#3A7A57;">Price</label>
              <input
                class="dark-input"
                type="number"
                name="price"
                value={@material.price}
                min="0"
                step="0.01"
                inputmode="decimal"
                placeholder="—"
                style="color:#54B57E;"
              />
            </div>
          </div>
          <div :if={@show_date} style="margin-top:12px;">
            <label class="dark-label">Planting date</label>
            <input
              class="dark-input"
              type="date"
              name="scheduled_date"
              value={@material.scheduled_date}
              style="color-scheme:dark;"
            />
          </div>
          <div style="margin-top:16px;">
            <.glow_button type="submit" valid={false}>Save</.glow_button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  # latin_name + cultivar if present, falls back to name
  defp catalog_item_title(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name || "—"
      title -> title
    end
  end
end
