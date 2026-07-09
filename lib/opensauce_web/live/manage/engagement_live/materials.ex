defmodule OpenSauceWeb.EngagementLive.Materials do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauceWeb.HtmlHelpers
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:format_filter, nil)
     |> assign(:editing_material, nil)
     |> assign(:date_lines, [])
     |> assign(:selected_date, nil)
     |> assign(:adding_date_line, false)
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

    date_lines = derive_date_lines(engagement.materials, socket.assigns[:date_lines] || [])

    {:noreply,
     socket
     |> assign(:reference, reference)
     |> assign(:engagement, engagement)
     |> assign(:plan_map, build_plan_map(engagement.materials))
     |> assign(:date_lines, date_lines)
     |> assign(:page_title, "Plan materials")}
  end

  def handle_event("set_date_context", %{"date" => ""}, socket) do
    {:noreply, assign(socket, :selected_date, nil)}
  end

  def handle_event("set_date_context", %{"date" => date_str}, socket) do
    {:ok, date} = Date.from_iso8601(date_str)
    {:noreply, assign(socket, :selected_date, date)}
  end

  def handle_event("start_add_date_line", _, socket) do
    {:noreply, assign(socket, :adding_date_line, true)}
  end

  def handle_event("confirm_date_line", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        {:noreply,
         socket
         |> update(:date_lines, fn lines -> Enum.sort(Enum.uniq([date | lines])) end)
         |> assign(:selected_date, date)
         |> assign(:adding_date_line, false)}

      _ ->
        {:noreply, assign(socket, :adding_date_line, false)}
    end
  end

  def handle_event("cancel_add_date_line", _, socket) do
    {:noreply, assign(socket, :adding_date_line, false)}
  end

  def handle_event("clear_search", _, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:format_filter, nil)}
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

  def handle_event("open_material_sheet", %{"id" => em_id}, socket) do
    em = Enum.find(socket.assigns.engagement.materials, &(&1.id == em_id))
    {:noreply, assign(socket, :editing_material, em)}
  end

  def handle_event("close_material_sheet", _params, socket) do
    {:noreply, assign(socket, :editing_material, nil)}
  end

  def handle_event("save_material_sheet", params, socket) do
    member = socket.assigns.current_member
    em = socket.assigns.editing_material

    attrs = %{
      quantity: parse_decimal(params["nb"]),
      cost: parse_optional_decimal(params["cost"]),
      price: parse_optional_decimal(params["price"]),
      scheduled_date: parse_optional_date(params["scheduled_date"])
    }

    case CRM.update_engagement_material(em, attrs, actor: member, tenant: member.organisation_id) do
      {:ok, _} -> {:noreply, socket |> assign(:editing_material, nil) |> reload()}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not save.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:80px;">
      <.material_search_header
        search_query={@search_query}
        placeholder="Latin name, cultivar, or common name…"
      >
        <:nav>
          <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}"}>
            <button
              type="button"
              ontouchstart=""
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
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
          <div style="text-align:center;">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;line-height:1.1;">
              Plan materials
            </p>
            <p style="font-size:11px;color:#9A9384;margin-top:1px;">
              {customer_short_name(@engagement.customer)} · {@engagement.scope_title || "Engagement"}
            </p>
          </div>
          <.link navigate={~p"/manage/customers/#{@reference}/engagements/#{@engagement.id}"}>
            <button
              type="button"
              ontouchstart=""
              style="font-size:13px;font-weight:700;color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;"
            >
              Done
            </button>
          </.link>
        </:nav>
      </.material_search_header>

      <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:12px;">
        <%!-- format filter chips --%>
        <div
          :if={@search_results != [] and format_options(@search_results) != []}
          style="display:flex;gap:6px;flex-wrap:wrap;"
        >
          <button
            :for={fmt <- format_options(@search_results)}
            type="button"
            phx-click="set_format_filter"
            phx-value-fmt={fmt}
            ontouchstart=""
            style={"font-size:12px;font-weight:600;padding:4px 10px;border-radius:20px;border:1px solid rgba(52,48,37,0.58);cursor:pointer;#{if @format_filter == fmt, do: "background:#54B57E;color:#0C1F15;border-color:#54B57E;", else: "background:#211E16;color:#9A9384;"}"}
          >
            {fmt}
          </button>
        </div>

        <%!-- search results --%>
        <div
          :if={@search_query != "" and @search_results == []}
          style="font-size:13px;color:#6E675A;text-align:center;padding:20px 0;"
        >
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
          <div style="display:flex;flex-direction:column;gap:16px;margin-bottom:12px;">
            <div :for={{date, items} <- display_groups(@engagement.materials, @date_lines)}>
              <div
                phx-click="set_date_context"
                phx-value-date={if is_nil(date), do: "", else: Date.to_iso8601(date)}
                ontouchstart=""
                style={"display:flex;align-items:center;gap:8px;cursor:pointer;#{if items == [], do: "", else: "margin-bottom:8px;"}"}
              >
                <span style={"font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;white-space:nowrap;#{if @selected_date == date, do: "color:#54B57E;", else: "color:#6E675A;"}"}>
                  {date_group_label(date, @engagement.term_start)}
                </span>
                <div style={"flex:1;height:1px;#{if @selected_date == date, do: "background:rgba(84,181,126,0.35);", else: "background:rgba(52,48,37,0.58);"}"}>
                </div>
                <svg
                  :if={@selected_date == date}
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
              <div :if={items != []} style="display:flex;flex-direction:column;gap:6px;">
                <.material_line
                  :for={em <- items}
                  jm={em}
                  currency={@organisation.currency}
                  on_tap={JS.push("open_material_sheet", value: %{id: em.id})}
                  on_remove={JS.push("remove_plan_item", value: %{id: em.id})}
                />
              </div>
            </div>
            <p
              :if={@engagement.materials == []}
              style="font-size:13px;color:#6E675A;text-align:center;padding:2px 0 6px;"
            >
              search above to add plants
            </p>
          </div>
          <form
            :if={@adding_date_line}
            phx-submit="confirm_date_line"
            style="display:flex;align-items:center;gap:8px;"
          >
            <input
              type="date"
              name="date"
              class="dark-input"
              style="flex:1;color-scheme:dark;"
              autofocus
            />
            <button
              type="submit"
              ontouchstart=""
              style="background:#54B57E;color:#0C1F15;border:none;border-radius:8px;padding:8px 14px;font-size:13px;font-weight:700;cursor:pointer;white-space:nowrap;"
            >
              Add
            </button>
            <button
              type="button"
              phx-click="cancel_add_date_line"
              ontouchstart=""
              style="background:none;border:none;color:#6E675A;font-size:16px;cursor:pointer;padding:4px 8px;line-height:1;"
            >
              ✕
            </button>
          </form>
          <button
            :if={!@adding_date_line}
            type="button"
            phx-click="start_add_date_line"
            ontouchstart=""
            style="width:100%;border-radius:12px;border:1.5px dashed rgba(84,181,126,0.3);padding:10px;background:none;cursor:pointer;display:flex;align-items:center;justify-content:center;color:#54B57E;"
          >
            <.add_job_icon />
          </button>
        </div>
      </div>

      <%!-- sticky summary bar --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;z-index:10;">
        <div style="display:flex;align-items:center;justify-content:center;gap:16px;">
          <span style="font-size:13px;color:#9A9384;">
            {length(@engagement.materials)} {if length(@engagement.materials) == 1,
              do: "item",
              else: "items"}
          </span>
          <span style="font-size:13px;font-weight:700;color:#DB9258;">
            {HtmlHelpers.format_currency(
              @organisation.currency,
              materials_cost_total(@engagement.materials)
            )}
          </span>
          <span style="font-size:13px;font-weight:700;color:#54B57E;">
            {HtmlHelpers.format_currency(
              @organisation.currency,
              materials_price_total(@engagement.materials)
            )}
          </span>
        </div>
      </div>

      <.material_line_sheet
        material={@editing_material}
        currency={@organisation.currency}
        on_close={JS.push("close_material_sheet")}
        show_date={true}
      />
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
      <div
        :if={@plan_entry}
        style="display:flex;align-items:center;justify-content:space-between;margin-top:8px;"
      >
        <div style="display:flex;align-items:center;gap:4px;">
          <button
            :if={@item.min_order_qty && @item.min_order_qty > 1}
            type="button"
            phx-click="sub_flat"
            phx-value-id={@item.id}
            ontouchstart=""
            style={stepper_btn_style()}
          >
            −f
          </button>
          <button
            type="button"
            phx-click="sub_one"
            phx-value-id={@item.id}
            ontouchstart=""
            style={stepper_btn_style()}
          >
            −1
          </button>
          <div style="min-width:52px;text-align:center;">
            <p style="font-size:17px;font-weight:700;color:#F4EFE2;line-height:1;">
              {@plan_entry.quantity}
            </p>
            <p
              :if={@item.min_order_qty && @item.min_order_qty > 1}
              style="font-size:10px;color:#9A9384;"
            >
              {Decimal.mult(@plan_entry.quantity, @item.min_order_qty)} plants
            </p>
          </div>
          <button
            type="button"
            phx-click="add_one"
            phx-value-id={@item.id}
            ontouchstart=""
            style={stepper_btn_style()}
          >
            +1
          </button>
          <button
            :if={@item.min_order_qty && @item.min_order_qty > 1}
            type="button"
            phx-click="add_flat"
            phx-value-id={@item.id}
            ontouchstart=""
            style={stepper_btn_style()}
          >
            +f
          </button>
        </div>
        <span
          :if={@plan_entry.scheduled_date}
          style="font-size:11px;color:#9A9384;background:rgba(52,48,37,0.58);padding:2px 8px;border-radius:10px;"
        >
          need {Calendar.strftime(@plan_entry.scheduled_date, "%a %d %b")}
        </span>
      </div>

      <%!-- add buttons if not on plan --%>
      <div :if={!@plan_entry} style="display:flex;gap:6px;margin-top:8px;">
        <button
          :if={@item.min_order_qty && @item.min_order_qty > 1}
          type="button"
          phx-click="add_flat"
          phx-value-id={@item.id}
          ontouchstart=""
          style={add_btn_style()}
        >
          + flat
        </button>
        <button
          type="button"
          phx-click="add_one"
          phx-value-id={@item.id}
          ontouchstart=""
          style={add_btn_style()}
        >
          + 1
        </button>
      </div>
    </div>
    """
  end

  defp stepper_btn_style,
    do:
      "background:#2B2820;border:1px solid rgba(52,48,37,0.58);border-radius:8px;color:#F4EFE2;font-size:12px;font-weight:600;padding:5px 9px;cursor:pointer;min-width:32px;"

  defp add_btn_style,
    do:
      "background:#2B2820;border:1px solid rgba(84,181,126,0.4);border-radius:8px;color:#54B57E;font-size:12px;font-weight:700;padding:6px 14px;cursor:pointer;"

  defp adjust_quantity(socket, catalog_item_id, item, delta) do
    member = socket.assigns.current_member
    engagement = socket.assigns.engagement

    case_result =
      case Map.get(socket.assigns.plan_map, catalog_item_id) do
        nil ->
          qty = max(delta, 1)
          {cost_val, price_val} = catalog_price(item)

          case CRM.create_engagement_material(
                 %{
                   engagement_id: engagement.id,
                   supplier_catalog_item_id: catalog_item_id,
                   quantity: Decimal.new(qty),
                   scheduled_date: socket.assigns.selected_date,
                   cost: cost_val,
                   price: price_val,
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
            case CRM.destroy_engagement_material(em,
                   actor: member,
                   tenant: member.organisation_id
                 ) do
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

    then(case_result, fn result ->
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
    |> update(:date_lines, &derive_date_lines(engagement.materials, &1))
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

  # Splits a catalog item's unit_price into {cost, price} based on catalog price_kind.
  # :cost catalogs → populate cost field, leave price nil (margin to be set later).
  # :msrp catalogs (or unspecified) → populate price field, leave cost nil.
  defp catalog_price(nil), do: {nil, nil}
  defp catalog_price(%{unit_price: nil}), do: {nil, nil}
  defp catalog_price(%{unit_price: p, supplier_catalog: %{price_kind: :cost}}), do: {p, nil}
  defp catalog_price(%{unit_price: p}), do: {nil, p}

  defp format_options(results) do
    results
    |> Enum.map(& &1.format_description)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp filtered_results(results, nil), do: results
  defp filtered_results(results, fmt), do: Enum.filter(results, &(&1.format_description == fmt))

  defp materials_cost_total(materials) do
    Enum.reduce(materials, Decimal.new(0), fn em, acc ->
      Decimal.add(acc, Decimal.mult(em.quantity, em.cost || Decimal.new(0)))
    end)
  end

  defp materials_price_total(materials) do
    Enum.reduce(materials, Decimal.new(0), fn em, acc ->
      Decimal.add(acc, Decimal.mult(em.quantity, em.price || Decimal.new(0)))
    end)
  end

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(""), do: Decimal.new(0)

  defp parse_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> Decimal.new(0)
    end
  end

  defp parse_optional_decimal(nil), do: nil
  defp parse_optional_decimal(""), do: nil

  defp parse_optional_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp parse_optional_date(nil), do: nil
  defp parse_optional_date(""), do: nil

  defp parse_optional_date(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  # Always renders a row for each known date (from date_lines + existing materials),
  # including empty ones — so a freshly-added date line is immediately selectable.
  defp display_groups(materials, date_lines) do
    grouped = Enum.group_by(materials, & &1.scheduled_date)

    all_dates =
      (date_lines ++ (materials |> Enum.map(& &1.scheduled_date) |> Enum.reject(&is_nil/1)))
      |> Enum.uniq()
      |> Enum.sort()

    undated = [{nil, Map.get(grouped, nil, [])}]
    dated = Enum.map(all_dates, fn d -> {d, Map.get(grouped, d, [])} end)
    undated ++ dated
  end

  defp date_group_label(nil, nil), do: "Plan"
  defp date_group_label(nil, term_start), do: Calendar.strftime(term_start, "%b %-d, %Y")
  defp date_group_label(date, _), do: Calendar.strftime(date, "%b %-d, %Y")

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

  # Merges dates from existing materials with any locally-added (unpersisted) date lines.
  defp derive_date_lines(materials, existing_lines) do
    from_materials =
      materials |> Enum.map(& &1.scheduled_date) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    (from_materials ++ existing_lines) |> Enum.uniq() |> Enum.sort()
  end
end
