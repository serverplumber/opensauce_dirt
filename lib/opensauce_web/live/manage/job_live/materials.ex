defmodule OpenSauceWeb.JobLive.Materials do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauce.Orders
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
  def handle_params(%{"id" => job_id}, _uri, socket) do
    member = socket.assigns.current_member

    job =
      Orders.get_job_by_id!(job_id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :garden,
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]],
          engagement: [:customer, materials: [:supplier_catalog_item]]
        ]
      )

    back_to = back_path(job)

    {:noreply,
     socket
     |> assign(:job, job)
     |> assign(:plan_item_ids, plan_item_ids(job))
     |> assign(:job_map, build_job_map(job.materials))
     |> assign(:back_to, back_to)
     |> assign(:page_title, "Job materials")}
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
    new = if socket.assigns.format_filter == fmt, do: nil, else: fmt
    {:noreply, assign(socket, :format_filter, new)}
  end

  def handle_event("add_one", %{"id" => catalog_item_id}, socket) do
    item = find_item(socket.assigns.search_results, catalog_item_id)
    adjust(socket, catalog_item_id, item, +1)
  end

  def handle_event("add_flat", %{"id" => catalog_item_id}, socket) do
    item = find_item(socket.assigns.search_results, catalog_item_id)
    adjust(socket, catalog_item_id, item, flat_size(item))
  end

  def handle_event("sub_one", %{"id" => catalog_item_id}, socket) do
    item = find_item_from_job(socket.assigns.job.materials, catalog_item_id)
    adjust(socket, catalog_item_id, item, -1)
  end

  def handle_event("sub_flat", %{"id" => catalog_item_id}, socket) do
    item = find_item_from_job(socket.assigns.job.materials, catalog_item_id)
    adjust(socket, catalog_item_id, item, -flat_size(item.supplier_catalog_item))
  end

  def handle_event("remove_item", %{"id" => jm_id}, socket) do
    member = socket.assigns.current_member
    jm = Enum.find(socket.assigns.job.materials, &(&1.id == jm_id))

    if jm do
      Orders.destroy_job_material(jm, actor: member, tenant: member.organisation_id)
      {:noreply, reload(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_from_plan", %{"id" => catalog_item_id}, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.job

    plan_item =
      job.engagement &&
        Enum.find(job.engagement.materials, &(&1.supplier_catalog_item_id == catalog_item_id))

    qty = (plan_item && plan_item.quantity) || Decimal.new(1)

    case Orders.create_job_material(
           %{
             job_id: job.id,
             supplier_catalog_item_id: catalog_item_id,
             quantity: qty,
             organisation_id: member.organisation_id
           },
           actor: member,
           tenant: member.organisation_id
         ) do
      {:ok, _} -> {:noreply, reload(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not add item.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:80px;">

      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={@back_to}>
          <button type="button" ontouchstart="" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        </.link>
        <div style="text-align:center;">
          <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:16px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;line-height:1.1;">Job materials</p>
          <p style="font-size:11px;color:#9A9384;margin-top:1px;">
            {job_subtitle(@job)}
          </p>
        </div>
        <.link navigate={@back_to}>
          <button type="button" ontouchstart="" style="font-size:13px;font-weight:700;color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;">
            Done
          </button>
        </.link>
      </div>

      <div style="padding:12px 16px 0;display:flex;flex-direction:column;gap:12px;">

        <%!-- engagement plan context --%>
        <div :if={@job.engagement}
          style="background:#211E16;border-radius:10px;border:1px solid rgba(52,48,37,0.58);padding:9px 12px;">
          <p style="font-size:11px;color:#6E675A;">↑ from engagement plan</p>
          <p style="font-size:11px;color:#9A9384;margin-top:2px;">
            {engagement_context(@job)} · {length(@job.engagement.materials)} planned
          </p>
        </div>

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
              job_entry={Map.get(@job_map, item.id)}
              from_plan={MapSet.member?(@plan_item_ids, item.id)}
              currency={@organisation.currency}
            />
          </div>
        </div>

        <%!-- current job items --%>
        <div :if={@search_query == ""}>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span style="font-size:10px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;">
              On this job
            </span>
          </div>
          <div :if={@job.materials == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No materials yet — search to add
          </div>
          <div :if={@job.materials != []} style="display:flex;flex-direction:column;gap:6px;">
            <div :for={jm <- @job.materials}
              style={"background:#211E16;border-radius:12px;padding:10px 12px;border:1px solid #{if MapSet.member?(@plan_item_ids, jm.supplier_catalog_item_id), do: "#54B57E", else: "rgba(52,48,37,0.58)"};"}>
              <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
                <div style="flex:1;min-width:0;">
                  <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {catalog_item_title(jm.supplier_catalog_item)}
                  </p>
                  <p style="font-size:11px;color:#9A9384;margin-top:2px;">
                    {jm.supplier_catalog_item.supplier_catalog.supplier.name}
                    {if jm.supplier_catalog_item.format_description, do: " · #{jm.supplier_catalog_item.format_description}"}
                    {if MapSet.member?(@plan_item_ids, jm.supplier_catalog_item_id), do: " · from plan"}
                  </p>
                </div>
                <div style="display:flex;align-items:center;gap:8px;flex-shrink:0;">
                  <div style="display:flex;align-items:center;gap:4px;">
                    <button type="button"
                      phx-click="sub_one"
                      phx-value-id={jm.supplier_catalog_item_id}
                      ontouchstart=""
                      style={stepper_btn_style()}>
                      −1
                    </button>
                    <span style="font-size:16px;font-weight:700;color:#F4EFE2;min-width:32px;text-align:center;">{jm.quantity}</span>
                    <button type="button"
                      phx-click="add_one"
                      phx-value-id={jm.supplier_catalog_item_id}
                      ontouchstart=""
                      style={stepper_btn_style()}>
                      +1
                    </button>
                  </div>
                  <button type="button" phx-click="remove_item" phx-value-id={jm.id} ontouchstart=""
                    style="background:none;border:none;color:#6E675A;cursor:pointer;padding:4px;line-height:0;">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none">
                      <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          </div>

          <%!-- plan items not yet on job --%>
          <div :if={@job.engagement && unplanned_items(@job) != []} style="margin-top:12px;">
            <p style="font-size:10px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
              From plan — not added yet
            </p>
            <div style="display:flex;flex-direction:column;gap:6px;">
              <div :for={em <- unplanned_items(@job)}
                style="background:#211E16;border-radius:12px;padding:10px 12px;border:1px solid rgba(52,48,37,0.58);display:flex;align-items:center;gap:10px;">
                <div style="flex:1;min-width:0;">
                  <p style="font-size:13px;font-weight:600;font-style:italic;color:#9A9384;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {catalog_item_title(em.supplier_catalog_item)}
                  </p>
                  <p style="font-size:11px;color:#6E675A;margin-top:2px;">
                    plan qty: {em.quantity}
                  </p>
                </div>
                <button type="button"
                  phx-click="add_from_plan"
                  phx-value-id={em.supplier_catalog_item_id}
                  ontouchstart=""
                  style="font-size:12px;font-weight:700;color:#54B57E;background:rgba(84,181,126,0.12);border:1px solid rgba(84,181,126,0.3);border-radius:8px;padding:5px 10px;cursor:pointer;">
                  + add
                </button>
              </div>
            </div>
          </div>
        </div>

      </div>

      <%!-- sticky summary bar --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;display:flex;align-items:center;justify-content:space-between;z-index:10;">
        <span style="font-size:13px;color:#9A9384;">
          {length(@job.materials)} {if length(@job.materials) == 1, do: "item", else: "items"}
          · {HtmlHelpers.format_currency(@organisation.currency, job_cost(@job.materials))}
        </span>
        <.link navigate={@back_to}>
          <span ontouchstart="" style="font-size:13px;font-weight:700;color:#54B57E;cursor:pointer;">
            back to job →
          </span>
        </.link>
      </div>

    </div>
    """
  end

  attr :item, :map, required: true
  attr :job_entry, :map, default: nil
  attr :from_plan, :boolean, default: false
  attr :currency, :atom, required: true

  defp catalog_card(assigns) do
    ~H"""
    <div style={"background:#211E16;border-radius:12px;padding:12px;border:1px solid #{if @job_entry, do: "#54B57E", else: "rgba(52,48,37,0.58)"};"}>
      <div style="display:flex;align-items:baseline;justify-content:space-between;gap:8px;">
        <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
          {catalog_item_title(@item)}
        </p>
        <span style="font-size:11px;color:#9A9384;flex-shrink:0;">
          {price_label(@item, @currency)}
        </span>
      </div>
      <p style="font-size:11px;color:#6E675A;margin-top:3px;">
        {@item.supplier_catalog.supplier.name}
        {if @item.format_description, do: " · #{@item.format_description}"}
        {if @item.min_order_qty && @item.min_order_qty > 1, do: " · #{@item.min_order_qty}/flat"}
        {if @from_plan, do: " · in plan"}
      </p>

      <%!-- stepper if on job --%>
      <div :if={@job_entry} style="display:flex;align-items:center;gap:4px;margin-top:8px;">
        <button :if={@item.min_order_qty && @item.min_order_qty > 1}
          type="button" phx-click="sub_flat" phx-value-id={@item.id} ontouchstart=""
          style={stepper_btn_style()}>
          −f
        </button>
        <button type="button" phx-click="sub_one" phx-value-id={@item.id} ontouchstart=""
          style={stepper_btn_style()}>
          −1
        </button>
        <div style="min-width:48px;text-align:center;">
          <p style="font-size:17px;font-weight:700;color:#F4EFE2;line-height:1;">{@job_entry.quantity}</p>
          <p :if={@item.min_order_qty && @item.min_order_qty > 1} style="font-size:10px;color:#9A9384;">
            {Decimal.mult(@job_entry.quantity, @item.min_order_qty)} plants
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

      <%!-- add buttons if not on job --%>
      <div :if={!@job_entry} style="display:flex;gap:6px;margin-top:8px;">
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

  defp adjust(socket, catalog_item_id, item, delta) do
    member = socket.assigns.current_member
    job = socket.assigns.job

    case Map.get(socket.assigns.job_map, catalog_item_id) do
      nil ->
        qty = max(delta, 1)

        case Orders.create_job_material(
               %{
                 job_id: job.id,
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

      jm ->
        new_qty = Decimal.add(jm.quantity, Decimal.new(delta))

        if Decimal.compare(new_qty, Decimal.new(0)) != :gt do
          case Orders.destroy_job_material(jm, actor: member, tenant: member.organisation_id) do
            :ok -> {:noreply, reload(socket)}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Could not remove item.")}
          end
        else
          case Orders.update_job_material(jm, %{quantity: new_qty},
                 actor: member,
                 tenant: member.organisation_id
               ) do
            {:ok, _} -> {:noreply, reload(socket)}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update quantity.")}
          end
        end
    end
  end

  defp reload(socket) do
    member = socket.assigns.current_member

    job =
      Orders.get_job_by_id!(socket.assigns.job.id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :garden,
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]],
          engagement: [:customer, materials: [:supplier_catalog_item]]
        ]
      )

    socket
    |> assign(:job, job)
    |> assign(:job_map, build_job_map(job.materials))
  end

  defp build_job_map(materials) do
    Map.new(materials, &{&1.supplier_catalog_item_id, &1})
  end

  defp plan_item_ids(%{engagement: nil}), do: MapSet.new()
  defp plan_item_ids(%{engagement: %Ash.NotLoaded{}}), do: MapSet.new()

  defp plan_item_ids(%{engagement: engagement}) do
    MapSet.new(engagement.materials, & &1.supplier_catalog_item_id)
  end

  defp unplanned_items(%{engagement: nil}), do: []
  defp unplanned_items(%{engagement: %Ash.NotLoaded{}}), do: []

  defp unplanned_items(%{materials: job_materials, engagement: engagement}) do
    job_ids = MapSet.new(job_materials, & &1.supplier_catalog_item_id)
    Enum.reject(engagement.materials, &MapSet.member?(job_ids, &1.supplier_catalog_item_id))
  end

  defp find_item(results, id), do: Enum.find(results, &(&1.id == id))

  defp find_item_from_job(materials, catalog_item_id) do
    jm = Enum.find(materials, &(&1.supplier_catalog_item_id == catalog_item_id))
    jm && jm.supplier_catalog_item
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

  defp job_cost(materials) do
    Enum.reduce(materials, Decimal.new(0), fn jm, acc ->
      unit = jm.supplier_catalog_item.unit_price || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(jm.quantity, unit))
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

  defp job_subtitle(%{service_category: cat, scheduled_for: date}) when not is_nil(cat) do
    label = Phoenix.Naming.humanize(cat)
    if date, do: "#{label} · #{Calendar.strftime(date, "%a %d %b")}", else: label
  end

  defp job_subtitle(%{scheduled_for: date}) when not is_nil(date) do
    Calendar.strftime(date, "%a %d %b")
  end

  defp job_subtitle(_), do: "Job"

  defp engagement_context(%{engagement: eng}) when not is_nil(eng) do
    customer = eng.customer
    name = if customer, do: customer.company_name_nickname || "#{customer.first_name} #{customer.last_name}", else: "—"
    "#{name} · #{eng.scope_title || "Engagement"}"
  end

  defp engagement_context(_), do: ""

  defp back_path(%{engagement: eng, engagement_id: eid}) when not is_nil(eid) do
    if eng && eng.customer do
      "/manage/customers/#{eng.customer.reference}/engagements/#{eid}"
    else
      "/manage/jobs"
    end
  end

  defp back_path(_), do: "/manage/jobs"
end
