defmodule OpenSauceWeb.EngagementLive.Materials do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:format_filter, nil)
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_params(%{"reference" => reference, "engagement_id" => engagement_id}, _uri, socket) do
    member = socket.assigns.current_member

    engagement =
      Ash.get!(CRM.Engagement, engagement_id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :customer,
          :garden,
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]
        ]
      )

    {:noreply,
     socket
     |> assign(:reference, reference)
     |> assign(:engagement, engagement)
     |> assign(:plan_map, build_plan_map(engagement.materials))
     |> assign(:page_title, "Plan materials")}
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

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)
     |> assign(:format_filter, nil)}
  end

  def handle_event("set_format_filter", %{"fmt" => fmt}, socket) do
    new_filter = if socket.assigns.format_filter == fmt, do: nil, else: fmt
    {:noreply, assign(socket, :format_filter, new_filter)}
  end

  def handle_event("add_one", %{"id" => catalog_item_id}, socket) do
    item = find_search_item(socket.assigns.search_results, catalog_item_id)
    adjust_quantity(socket, catalog_item_id, item, +1)
  end

  def handle_event("add_flat", %{"id" => catalog_item_id}, socket) do
    item = find_search_item(socket.assigns.search_results, catalog_item_id)
    delta = flat_size(item)
    adjust_quantity(socket, catalog_item_id, item, +delta)
  end

  def handle_event("sub_one", %{"id" => catalog_item_id}, socket) do
    item = find_search_item(socket.assigns.search_results, catalog_item_id)
    adjust_quantity(socket, catalog_item_id, item, -1)
  end

  def handle_event("sub_flat", %{"id" => catalog_item_id}, socket) do
    item = find_search_item(socket.assigns.search_results, catalog_item_id)
    delta = flat_size(item)
    adjust_quantity(socket, catalog_item_id, item, -delta)
  end

  def handle_event("remove_plan_item", %{"id" => em_id}, socket) do
    member = socket.assigns.current_member
    em = Enum.find(socket.assigns.engagement.materials, &(&1.id == em_id))

    if em do
      CRM.destroy_engagement_material(em, actor: member, tenant: member.organisation_id)
      {:noreply, reload(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:80px;">

      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}"}>
          <button type="button" ontouchstart="" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        </.link>
        <div style="text-align:center;">
          <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;line-height:1.1;">Plan materials</p>
          <p style="font-size:11px;color:#9A9384;margin-top:1px;">
            {customer_short_name(@engagement.customer)} · {@engagement.scope_title || "Engagement"}
          </p>
        </div>
        <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}"}>
          <button type="button" ontouchstart="" style="font-size:13px;font-weight:700;color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;">
            Done
          </button>
        </.link>
      </div>

      <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:12px;">

        <%!-- search --%>
        <form phx-change="search" style="position:relative;">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none"
            style="position:absolute;left:12px;top:50%;transform:translateY(-50%);color:#6E675A;pointer-events:none;">
            <circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="2"/>
            <path d="M21 21l-4.35-4.35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
          </svg>
          <input
            class="dark-input"
            type="search"
            name="q"
            value={@search_query}
            phx-debounce="300"
            autocomplete="off"
            placeholder="Latin name, cultivar, or common name…"
            style="padding-left:36px;"
          />
        </form>

        <%!-- format filter chips --%>
        <div :if={@search_results != [] and format_options(@search_results) != []}
          style="display:flex;gap:6px;flex-wrap:wrap;">
          <button :for={fmt <- format_options(@search_results)}
            type="button"
            phx-click="set_format_filter"
            phx-value-fmt={fmt}
            ontouchstart=""
            style={"font-size:12px;font-weight:600;padding:4px 10px;border-radius:20px;border:1px solid rgba(52,48,37,0.58);cursor:pointer;#{if @format_filter == fmt, do: "background:#54B57E;color:#0C1F15;border-color:#54B57E;", else: "background:#211E16;color:#9A9384;"}"}>
            {fmt}
          </button>
        </div>

        <%!-- search results --%>
        <div :if={@search_query != "" and @search_results == []}
          style="font-size:13px;color:#6E675A;text-align:center;padding:20px 0;">
          No results for "{@search_query}"
        </div>

        <div :if={@search_results != []} style="display:flex;flex-direction:column;gap:8px;">
          <div :for={item <- filtered_results(@search_results, @format_filter)}>
            <.catalog_card
              item={item}
              plan_entry={Map.get(@plan_map, item.id)}
              currency={@organisation.currency}
            />
          </div>
        </div>

        <%!-- plan list (when not searching) --%>
        <div :if={@search_query == ""}>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Current plan</span>
          </div>
          <div :if={@engagement.materials == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No materials yet — search to add
          </div>
          <div :if={@engagement.materials != []} style="display:flex;flex-direction:column;gap:6px;">
            <div :for={em <- @engagement.materials}
              style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;display:flex;align-items:center;gap:10px;">
              <div style="flex:1;min-width:0;">
                <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {catalog_item_title(em.supplier_catalog_item)}
                </p>
                <p style="font-size:11px;color:#9A9384;margin-top:2px;">
                  {em.supplier_catalog_item.supplier_catalog.supplier.name}
                  {if em.supplier_catalog_item.format_description, do: " · #{em.supplier_catalog_item.format_description}"}
                  {if em.scheduled_date, do: " · #{em.scheduled_date}"}
                </p>
              </div>
              <span style="font-size:15px;font-weight:700;color:#F4EFE2;flex-shrink:0;">×{em.quantity}</span>
              <button type="button" phx-click="remove_plan_item" phx-value-id={em.id} ontouchstart=""
                style="background:none;border:none;color:#6E675A;cursor:pointer;padding:4px;line-height:0;">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                </svg>
              </button>
            </div>
          </div>
        </div>

      </div>

      <%!-- sticky summary bar --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;display:flex;align-items:center;justify-content:space-between;z-index:10;">
        <span style="font-size:13px;color:#9A9384;">
          plan · {length(@engagement.materials)} {if length(@engagement.materials) == 1, do: "item", else: "items"}
          · est {HtmlHelpers.format_currency(@organisation.currency, plan_cost(@engagement.materials))}
        </span>
        <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}"}>
          <span ontouchstart="" style="font-size:13px;font-weight:700;color:#54B57E;cursor:pointer;">
            back to engagement →
          </span>
        </.link>
      </div>

    </div>
    """
  end

  attr :item, :map, required: true
  attr :plan_entry, :map, default: nil
  attr :currency, :atom, required: true

  defp catalog_card(assigns) do
    ~H"""
    <div style={"background:#211E16;border-radius:12px;padding:12px;border:1px solid #{if @plan_entry, do: "#54B57E", else: "rgba(52,48,37,0.58)"};"}>
      <div style="display:flex;align-items:baseline;justify-content:space-between;gap:8px;">
        <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
          {catalog_item_title(@item)}
        </p>
        <span style="font-size:11px;color:#9A9384;flex-shrink:0;white-space:nowrap;">
          {price_label(@item, @currency)}
        </span>
      </div>
      <p style="font-size:11px;color:#6E675A;margin-top:3px;">
        {@item.supplier_catalog.supplier.name}
        {if @item.format_description, do: " · #{@item.format_description}"}
        {if @item.min_order_qty && @item.min_order_qty > 1, do: " · #{@item.min_order_qty}/flat"}
      </p>

      <%!-- stepper if on plan --%>
      <div :if={@plan_entry} style="display:flex;align-items:center;justify-content:space-between;margin-top:8px;">
        <div style="display:flex;align-items:center;gap:4px;">
          <button :if={@item.min_order_qty && @item.min_order_qty > 1}
            type="button" phx-click="sub_flat" phx-value-id={@item.id} ontouchstart=""
            style={stepper_btn_style()}>
            −f
          </button>
          <button type="button" phx-click="sub_one" phx-value-id={@item.id} ontouchstart=""
            style={stepper_btn_style()}>
            −1
          </button>
          <div style="min-width:52px;text-align:center;">
            <p style="font-size:17px;font-weight:700;color:#F4EFE2;line-height:1;">{@plan_entry.quantity}</p>
            <p :if={@item.min_order_qty && @item.min_order_qty > 1}
              style="font-size:10px;color:#9A9384;">
              {Decimal.mult(@plan_entry.quantity, @item.min_order_qty)} plants
            </p>
          </div>
          <button type="button" phx-click="add_one" phx-value-id={@item.id} ontouchstart=""
            style={stepper_btn_style()}>
            +1
          </button>
          <button :if={@item.min_order_qty && @item.min_order_qty > 1}
            type="button" phx-click="add_flat" phx-value-id={@item.id} ontouchstart=""
            style={stepper_btn_style()}>
            +f
          </button>
        </div>
        <span :if={@plan_entry.scheduled_date}
          style="font-size:11px;color:#9A9384;background:rgba(52,48,37,0.58);padding:2px 8px;border-radius:10px;">
          need {Calendar.strftime(@plan_entry.scheduled_date, "%a %d %b")}
        </span>
      </div>

      <%!-- add buttons if not on plan --%>
      <div :if={!@plan_entry} style="display:flex;gap:6px;margin-top:8px;">
        <button :if={@item.min_order_qty && @item.min_order_qty > 1}
          type="button" phx-click="add_flat" phx-value-id={@item.id} ontouchstart=""
          style={add_btn_style()}>
          + flat
        </button>
        <button type="button" phx-click="add_one" phx-value-id={@item.id} ontouchstart=""
          style={add_btn_style()}>
          + 1
        </button>
      </div>
    </div>
    """
  end

  defp stepper_btn_style,
    do: "background:#2B2820;border:1px solid rgba(52,48,37,0.58);border-radius:8px;color:#F4EFE2;font-size:12px;font-weight:600;padding:5px 9px;cursor:pointer;min-width:32px;"

  defp add_btn_style,
    do: "background:#2B2820;border:1px solid rgba(84,181,126,0.4);border-radius:8px;color:#54B57E;font-size:12px;font-weight:700;padding:6px 14px;cursor:pointer;"

  defp adjust_quantity(socket, catalog_item_id, item, delta) do
    member = socket.assigns.current_member
    engagement = socket.assigns.engagement

    case Map.get(socket.assigns.plan_map, catalog_item_id) do
      nil ->
        qty = max(delta, 1)

        case CRM.create_engagement_material(
               %{
                 engagement_id: engagement.id,
                 supplier_catalog_item_id: catalog_item_id,
                 quantity: Decimal.new(qty),
                 organisation_id: member.organisation_id
               },
               actor: member,
               tenant: member.organisation_id
             ) do
          {:ok, _} -> {:noreply, reload(socket)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Could not add item.")}
        end

      em ->
        new_qty = Decimal.add(em.quantity, Decimal.new(delta))

        if Decimal.compare(new_qty, Decimal.new(0)) == :lt or
             Decimal.compare(new_qty, Decimal.new(0)) == :eq do
          case CRM.destroy_engagement_material(em, actor: member, tenant: member.organisation_id) do
            :ok -> {:noreply, reload(socket)}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Could not remove item.")}
          end
        else
          case CRM.update_engagement_material(em, %{quantity: new_qty},
                 actor: member,
                 tenant: member.organisation_id
               ) do
            {:ok, _} -> {:noreply, reload(socket)}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update quantity.")}
          end
        end
    end

    |> then(fn result ->
      case result do
        {:noreply, socket} -> {:noreply, socket}
        other -> other
      end
    end)
  end

  defp reload(socket) do
    member = socket.assigns.current_member

    engagement =
      Ash.get!(CRM.Engagement, socket.assigns.engagement.id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :customer,
          :garden,
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]
        ]
      )

    socket
    |> assign(:engagement, engagement)
    |> assign(:plan_map, build_plan_map(engagement.materials))
  end

  defp build_plan_map(materials) do
    Map.new(materials, &{&1.supplier_catalog_item_id, &1})
  end

  defp find_search_item(results, id) do
    Enum.find(results, &(&1.id == id))
  end

  defp flat_size(nil), do: 1
  defp flat_size(%{min_order_qty: nil}), do: 1
  defp flat_size(%{min_order_qty: n}), do: n

  defp format_options(results) do
    results
    |> Enum.map(& &1.format_description)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp filtered_results(results, nil), do: results
  defp filtered_results(results, fmt), do: Enum.filter(results, &(&1.format_description == fmt))

  defp plan_cost(materials) do
    Enum.reduce(materials, Decimal.new(0), fn em, acc ->
      unit = em.supplier_catalog_item.unit_price || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(em.quantity, unit))
    end)
  end

  defp price_label(item, currency) do
    case item.unit_price do
      nil -> "— ✎"
      price -> "#{HtmlHelpers.format_currency(currency, price)}/unit ✎"
    end
  end

  defp catalog_item_title(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name || "—"
      title -> title
    end
  end

  defp customer_short_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  defp customer_short_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"
end
