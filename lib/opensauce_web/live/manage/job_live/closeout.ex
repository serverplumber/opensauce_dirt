defmodule OpenSauceWeb.JobLive.Closeout do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory
  alias OpenSauce.Work
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:materials, [])
     |> assign(:odometer, "")
     |> assign(:note, "")
     |> assign(:show_add_sheet, false)
     |> assign(:sheet_query, "")
     |> assign(:sheet_results, [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    member = socket.assigns.current_member

    job =
      Work.get_job_by_id!(id,
        actor: member,
        tenant: member.organisation_id,
        load: [
          :garden,
          engagement: [:customer],
          staff_assignments: [member: [:user]],
          materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]
        ]
      )

    events =
      Work.list_job_events!(job.id, actor: member, tenant: member.organisation_id)

    {:noreply,
     socket
     |> assign(:job, job)
     |> assign(:materials, initial_materials(job))
     |> assign(:odometer, arrival_odometer(events))
     |> assign(:page_title, "Close out")}
  end

  @impl true
  def handle_event("update_fields", params, socket) do
    {:noreply,
     socket
     |> assign(:odometer, params["odometer"] || socket.assigns.odometer)
     |> assign(:note, params["note"] || socket.assigns.note)}
  end

  @impl true
  def handle_event("open_sheet", _params, socket) do
    {:noreply, assign(socket, show_add_sheet: true, sheet_query: "", sheet_results: [])}
  end

  @impl true
  def handle_event("close_sheet", _params, socket) do
    {:noreply, assign(socket, show_add_sheet: false, sheet_query: "", sheet_results: [])}
  end

  @impl true
  def handle_event("search_sheet", %{"q" => query}, socket) do
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

    {:noreply, assign(socket, sheet_query: query, sheet_results: results)}
  end

  @impl true
  def handle_event("add_from_plan", %{"id" => catalog_item_id}, socket) do
    jm =
      Enum.find(socket.assigns.job.materials, &(&1.supplier_catalog_item_id == catalog_item_id))

    if jm do
      {:noreply,
       socket
       |> upsert_material(jm.supplier_catalog_item, jm.quantity)
       |> assign(show_add_sheet: false, sheet_query: "", sheet_results: [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_from_search", %{"id" => catalog_item_id}, socket) do
    item =
      Enum.find(socket.assigns.sheet_results, &(&1.id == catalog_item_id)) ||
        (Enum.find(
           socket.assigns.job.materials,
           &(&1.supplier_catalog_item_id == catalog_item_id)
         ) &&
           Enum.find(
             socket.assigns.job.materials,
             &(&1.supplier_catalog_item_id == catalog_item_id)
           ).supplier_catalog_item)

    if item do
      {:noreply,
       socket
       |> upsert_material(item, Decimal.new(1))
       |> assign(show_add_sheet: false, sheet_query: "", sheet_results: [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("adj_qty", %{"id" => id, "delta" => delta_str}, socket) do
    delta = String.to_integer(delta_str)

    materials =
      socket.assigns.materials
      |> Enum.map(fn m ->
        if m.catalog_item.id == id do
          %{m | quantity: Decimal.add(m.quantity, Decimal.new(delta))}
        else
          m
        end
      end)
      |> Enum.reject(&(Decimal.compare(&1.quantity, Decimal.new(0)) != :gt))

    {:noreply, assign(socket, :materials, materials)}
  end

  @impl true
  def handle_event("remove_material", %{"id" => id}, socket) do
    {:noreply,
     assign(
       socket,
       :materials,
       Enum.reject(socket.assigns.materials, &(&1.catalog_item.id == id))
     )}
  end

  @impl true
  def handle_event("complete", _params, socket) do
    member = socket.assigns.current_member
    job = socket.assigns.job
    opts = [actor: member, tenant: member.organisation_id]
    now = DateTime.truncate(DateTime.utc_now(), :second)

    odometer_km =
      case Integer.parse(socket.assigns.odometer) do
        {n, _} -> n
        :error -> nil
      end

    note = if socket.assigns.note == "", do: nil, else: socket.assigns.note

    event =
      Work.log_job_event!(
        %{
          job_id: job.id,
          timestamp: now,
          data: %{type: :departure, odometer_km: odometer_km},
          note: note,
          organisation_id: member.organisation_id
        },
        opts
      )

    Enum.each(job.staff_assignments, fn sa ->
      Work.log_job_event_staff(
        %{
          job_event_id: event.id,
          member_id: sa.member_id,
          man_hour_rate: sa.member.labor_hourly_rate,
          organisation_id: member.organisation_id
        },
        opts
      )
    end)

    Work.complete_job(job, opts)

    {:noreply, push_navigate(socket, to: ~p"/manage/jobs", replace: true)}
  end

  @impl true
  def handle_event("back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manage/jobs/#{socket.assigns.job.id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:130px;">
      <%!-- top bar --%>
      <div style="display:flex;align-items:flex-start;justify-content:space-between;padding:14px 16px 0;">
        <div>
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;margin:0;line-height:1.1;">
            Close out
          </h1>
          <p style="font-size:11px;color:#6E675A;margin-top:3px;">
            {garden_label(@job)} · manager entry
          </p>
        </div>
        <.link navigate={~p"/manage/jobs/#{@job.id}"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:6px;cursor:pointer;line-height:0;margin-top:2px;"
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

      <form
        phx-change="update_fields"
        style="padding:16px 16px 0;display:flex;flex-direction:column;gap:14px;"
      >
        <%!-- info banner --%>
        <div style="border-radius:10px;border:1.5px dashed rgba(52,48,37,0.58);background:#211E16;padding:10px 12px;">
          <p style="font-size:12px;color:#9A9384;">
            ⓘ Staff already left — log what was done &amp; used to close the job.
          </p>
        </div>

        <%!-- odometer leaving --%>
        <div style="background:#211E16;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);padding:14px;">
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Odometer leaving
          </p>
          <div style="display:flex;align-items:baseline;gap:8px;">
            <input
              type="number"
              name="odometer"
              value={@odometer}
              placeholder="—"
              min="0"
              step="1"
              style="background:none;border:none;outline:none;font-size:34px;font-weight:700;color:#F4EFE2;width:100%;max-width:180px;font-family:'Bricolage Grotesque',sans-serif;letter-spacing:-0.02em;"
            />
            <span style="font-size:14px;color:#9A9384;">km</span>
          </div>
          <p style="font-size:11px;color:#6E675A;margin-top:4px;">tap to edit</p>
        </div>

        <%!-- materials used --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin:0;">
              Materials used
            </p>
            <button
              type="button"
              phx-click="open_sheet"
              ontouchstart=""
              style="display:flex;align-items:center;gap:4px;font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
                <path
                  d="M12 5v14M5 12h14"
                  stroke="currentColor"
                  stroke-width="2.2"
                  stroke-linecap="round"
                />
              </svg>
              add
            </button>
          </div>

          <div
            :if={@materials == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;"
          >
            No materials yet — tap + add
          </div>

          <div :if={@materials != []} style="display:flex;flex-direction:column;gap:6px;">
            <div
              :for={m <- @materials}
              style="background:#211E16;border-radius:12px;padding:10px 12px;border:1px solid rgba(52,48,37,0.58);"
            >
              <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
                <div style="flex:1;min-width:0;">
                  <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {catalog_item_name(m.catalog_item)}
                  </p>
                  <p style="font-size:11px;color:#9A9384;margin-top:2px;">
                    {supplier_label(m.catalog_item)}
                  </p>
                </div>
                <div style="display:flex;align-items:center;gap:6px;flex-shrink:0;">
                  <button
                    type="button"
                    phx-click="adj_qty"
                    phx-value-id={m.catalog_item.id}
                    phx-value-delta="-1"
                    ontouchstart=""
                    style={stepper_btn_style()}
                  >
                    −
                  </button>
                  <span style="font-size:16px;font-weight:700;color:#F4EFE2;min-width:28px;text-align:center;">
                    {m.quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="adj_qty"
                    phx-value-id={m.catalog_item.id}
                    phx-value-delta="1"
                    ontouchstart=""
                    style={stepper_btn_style()}
                  >
                    +
                  </button>
                  <button
                    type="button"
                    phx-click="remove_material"
                    phx-value-id={m.catalog_item.id}
                    ontouchstart=""
                    style="background:none;border:none;color:#6E675A;cursor:pointer;padding:4px;line-height:0;margin-left:2px;"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
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
              <%!-- planned qty context --%>
              <p
                :if={planned_qty(@job, m.catalog_item.id)}
                style="font-size:11px;color:#6E675A;margin-top:4px;"
              >
                planned {planned_qty(@job, m.catalog_item.id)}
              </p>
            </div>
          </div>
        </div>

        <%!-- staff placeholder (same as G2) --%>
        <div>
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Staff
          </p>
          <div style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px 14px;">
            <div
              :if={@job.staff_assignments && @job.staff_assignments != []}
              style="display:flex;flex-direction:column;gap:10px;"
            >
              <div
                :for={sa <- @job.staff_assignments}
                style="display:flex;align-items:center;gap:10px;"
              >
                <div class="av" style={"background:#{crew_color(sa.member_id)}"}>
                  {crew_initial(sa.member)}
                </div>
                <span style="font-size:13px;font-weight:600;color:#F4EFE2;">
                  {member_name(sa.member)}
                </span>
              </div>
            </div>
            <p
              :if={!@job.staff_assignments || @job.staff_assignments == []}
              style="font-size:13px;color:#6E675A;"
            >
              No crew assigned
            </p>
            <p style="font-size:11px;color:#6E675A;margin-top:10px;padding-top:10px;border-top:1px solid rgba(52,48,37,0.58);">
              Staff check-in coming soon
            </p>
          </div>
        </div>

        <%!-- note --%>
        <div>
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Notes — what's left to do, customer feedback…
          </p>
          <textarea
            name="note"
            class="dark-textarea"
            rows="4"
            placeholder="Anything to hand off for next visit…"
            phx-debounce="blur"
          >{@note}</textarea>
        </div>
      </form>

      <%!-- sticky CTAs --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:10px 16px;display:flex;gap:10px;z-index:10;">
        <button
          type="button"
          phx-click="back"
          ontouchstart=""
          style="flex:1;height:56px;border-radius:14px;background:#211E16;border:1px solid rgba(52,48,37,0.58);color:#9A9384;font-size:15px;font-weight:700;cursor:pointer;"
        >
          ← back
        </button>
        <div style="flex:2;">
          <.glow_button phx-click="complete" valid={true}>
            Complete &amp; leave →
          </.glow_button>
        </div>
      </div>

      <%!-- add material bottom sheet --%>
      <div
        :if={@show_add_sheet}
        style="position:fixed;inset:0;z-index:50;display:flex;flex-direction:column;justify-content:flex-end;"
      >
        <%!-- backdrop --%>
        <div
          phx-click="close_sheet"
          style="position:absolute;inset:0;background:rgba(0,0,0,0.65);"
        >
        </div>

        <%!-- sheet --%>
        <div style="position:relative;background:#211E16;border-radius:20px 20px 0 0;padding:0 0 100px;max-height:85vh;display:flex;flex-direction:column;">
          <%!-- sheet handle + header --%>
          <div style="padding:12px 16px 10px;border-bottom:1px solid rgba(52,48,37,0.58);flex-shrink:0;">
            <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 12px;">
            </div>
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Add material</span>
              <button
                type="button"
                phx-click="close_sheet"
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
            <%!-- search --%>
            <form phx-change="search_sheet" style="position:relative;margin-top:10px;">
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
                type="search"
                name="q"
                value={@sheet_query}
                phx-debounce="300"
                autocomplete="off"
                placeholder="Search catalog…"
                style="padding-left:36px;"
              />
            </form>
          </div>

          <%!-- sheet content --%>
          <div
            class="mobile-scroll"
            style="overflow-y:auto;padding:12px 16px 0;display:flex;flex-direction:column;gap:10px;"
          >
            <%!-- search results --%>
            <div :if={@sheet_query != ""}>
              <div
                :if={@sheet_results == []}
                style="font-size:13px;color:#6E675A;text-align:center;padding:20px 0;"
              >
                No results for "{@sheet_query}"
              </div>
              <div :if={@sheet_results != []} style="display:flex;flex-direction:column;gap:6px;">
                <div :for={item <- @sheet_results}>
                  <.sheet_item item={item} />
                </div>
              </div>
            </div>

            <%!-- from job plan --%>
            <div :if={@sheet_query == ""}>
              <div :if={@job.materials != []}>
                <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
                  From job plan
                </p>
                <div style="display:flex;flex-direction:column;gap:6px;">
                  <div :for={jm <- @job.materials}>
                    <.sheet_item
                      item={jm.supplier_catalog_item}
                      from_plan={true}
                      planned_qty={jm.quantity}
                    />
                  </div>
                </div>
              </div>
              <div
                :if={@job.materials == []}
                style="font-size:13px;color:#6E675A;text-align:center;padding:20px 0;"
              >
                No planned materials on this job — search to add
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :from_plan, :boolean, default: false
  attr :planned_qty, :any, default: nil

  defp sheet_item(assigns) do
    ~H"""
    <div style="background:#2B2820;border-radius:12px;padding:10px 12px;border:1px solid rgba(52,48,37,0.58);">
      <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
        <div style="flex:1;min-width:0;">
          <p style="font-size:13px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {catalog_item_name(@item)}
          </p>
          <p style="font-size:11px;color:#6E675A;margin-top:2px;">
            {supplier_label(@item)}
            <span :if={@from_plan} style="color:#54B57E;"> · plan:             {@planned_qty}</span>
          </p>
        </div>
        <button
          type="button"
          phx-click={if @from_plan, do: "add_from_plan", else: "add_from_search"}
          phx-value-id={@item.id}
          ontouchstart=""
          style="font-size:12px;font-weight:700;color:#54B57E;background:rgba(84,181,126,0.12);border:1px solid rgba(84,181,126,0.3);border-radius:8px;padding:5px 12px;cursor:pointer;flex-shrink:0;"
        >
          + add
        </button>
      </div>
    </div>
    """
  end

  defp arrival_odometer(events) do
    events
    |> Enum.filter(&match?(%{data: %Ash.Union{type: :arrival}}, &1))
    |> List.last()
    |> case do
      %{data: %Ash.Union{value: %{odometer_km: km}}} when not is_nil(km) -> to_string(km)
      _ -> ""
    end
  end

  defp initial_materials(job) do
    Enum.map(job.materials, fn jm ->
      %{catalog_item: jm.supplier_catalog_item, quantity: jm.quantity}
    end)
  end

  defp upsert_material(socket, catalog_item, qty) do
    materials = socket.assigns.materials

    case Enum.find_index(materials, &(&1.catalog_item.id == catalog_item.id)) do
      nil ->
        assign(socket, :materials, materials ++ [%{catalog_item: catalog_item, quantity: qty}])

      idx ->
        existing = Enum.at(materials, idx)
        updated = %{existing | quantity: Decimal.add(existing.quantity, qty)}
        assign(socket, :materials, List.replace_at(materials, idx, updated))
    end
  end

  defp planned_qty(job, catalog_item_id) do
    case Enum.find(job.materials, &(&1.supplier_catalog_item_id == catalog_item_id)) do
      nil -> nil
      jm -> jm.quantity
    end
  end

  defp catalog_item_name(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name || "—"
      title -> title
    end
  end

  defp supplier_label(%{supplier_catalog: %{supplier: %{name: name}}} = item) do
    parts = Enum.reject([name, item.format_description], &is_nil/1)
    Enum.join(parts, " · ")
  end

  defp supplier_label(item), do: item.format_description || ""

  defp garden_label(%{garden: %{name: n}}) when is_binary(n) and n != "", do: n
  defp garden_label(_), do: "No site"

  defp staff_name(%{user: %{email: e}}) when is_binary(e), do: e |> String.split("@") |> hd()
  defp staff_name(_), do: "?"

  defp crew_initial(member) do
    n = staff_name(member)
    if n == "?", do: "?", else: n |> String.first() |> String.upcase()
  end

  defp crew_color(member_id) do
    colors = ["#6BCB93", "#DB9258", "#5AB4D8", "#A87EDB", "#E87E7E"]
    Enum.at(colors, :erlang.phash2(member_id, length(colors)))
  end

  defp member_name(member), do: staff_name(member)

  defp stepper_btn_style,
    do:
      "background:#2B2820;border:1px solid rgba(52,48,37,0.58);border-radius:8px;color:#F4EFE2;font-size:14px;font-weight:600;padding:4px 10px;cursor:pointer;min-width:30px;"
end
