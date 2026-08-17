defmodule OpenSauceWeb.JobLive.Adhoc do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauce.Work

  @service_categories [
    {:maintenance, "Maintenance"},
    {:installation, "Install"},
    {:pruning, "Pruning"},
    {:delivery, "Delivery"},
    {:consultation, "Consult"},
    {:design, "Design"},
    {:opening, "Opening"},
    {:winterization, "Winterize"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    shift =
      case Work.find_active_shift!(opts) do
        [s | _] ->
          Work.get_job_by_id!(s.id, opts ++ [load: [staff_assignments: [member: []]]])

        [] ->
          nil
      end

    if is_nil(shift) do
      {:ok, push_navigate(socket, to: ~p"/manage/today")}
    else
      now = DateTime.utc_now()
      start_minutes = min(now.hour * 60 + div(now.minute, 15) * 15, 1260)

      all_gardens =
        CRM.list_gardens!(actor: member, tenant: member.organisation_id, load: [:customer])

      {:ok,
       socket
       |> assign(:page_title, "New Job")
       |> assign(:main_bg, "bg-[#16140E]")
       |> assign(:active_shift, shift)
       |> assign(:all_gardens, all_gardens)
       |> assign(:garden, nil)
       |> assign(:category, nil)
       |> assign(:timing, :now)
       |> assign(:start_minutes, start_minutes)
       |> assign(:duration_minutes, 60)
       |> assign(:garden_search, "")
       |> assign(:show_garden_picker, false)
       |> assign(:service_categories, @service_categories)
       |> assign(:draft_map, %{})
       |> assign(:show_materials_sheet, false)
       |> assign(:catalog_search, "")
       |> assign(:catalog_results, [])}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <div style="padding:0 16px 160px;">
        <%!-- header --%>
        <div style="display:flex;align-items:center;padding:12px 2px 0;">
          <.link navigate={~p"/manage/today"} style="color:#6E675A;line-height:0;padding:4px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M18 6L6 18M6 6l12 12"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
            </svg>
          </.link>
        </div>

        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:28px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;margin:16px 0 24px;">
          New job
        </h1>

        <%!-- garden --%>
        <div style="margin-bottom:20px;">
          <span class="dark-label">Garden / site</span>
          <button
            :if={is_nil(@garden)}
            type="button"
            phx-click="open_garden_picker"
            ontouchstart=""
            style="width:100%;border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);background:transparent;padding:11px 13px;font-size:13.5px;color:#6E675A;text-align:left;cursor:pointer;"
          >
            Pick a garden…
          </button>
          <button
            :if={@garden}
            type="button"
            phx-click="open_garden_picker"
            ontouchstart=""
            style="width:100%;border-radius:14px;border:1.5px solid #54B57E;background:rgba(84,181,126,0.10);padding:11px 13px;text-align:left;cursor:pointer;"
          >
            <p style="font-size:14px;font-weight:700;color:#F4EFE2;">
              {@garden.name || "Unnamed site"}
            </p>
            <p :if={@garden.street} style="font-size:12px;color:#9A9384;margin-top:2px;">
              {@garden.street}
            </p>
          </button>
        </div>

        <%!-- service category chips --%>
        <div style="margin-bottom:20px;">
          <span class="dark-label">Service</span>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
            <button
              :for={{cat, label} <- @service_categories}
              type="button"
              phx-click="set_category"
              phx-value-cat={cat}
              ontouchstart=""
              style={"border-radius:12px;border:1.5px solid;padding:10px 12px;font-size:13.5px;font-weight:700;cursor:pointer;text-align:left;#{if @category == cat, do: "background:#54B57E;color:#0C1F15;border-color:#54B57E;", else: "background:#211E16;color:#9A9384;border-color:rgba(52,48,37,0.58);"}"}
            >
              {label}
            </button>
          </div>
        </div>

        <%!-- starting / done toggle --%>
        <div style="margin-bottom:20px;">
          <span class="dark-label">Timing</span>
          <div style="display:flex;gap:4px;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:13px;padding:4px;">
            <button
              :for={{val, label} <- [{:now, "Starting"}, {:done, "Done"}]}
              type="button"
              phx-click="set_timing"
              phx-value-timing={val}
              ontouchstart=""
              class={["seg-tab", @timing == val && "seg-tab--on"]}
            >
              {label}
            </button>
          </div>
        </div>

        <%!-- done sliders --%>
        <div
          :if={@timing == :done}
          style="display:flex;flex-direction:column;gap:16px;margin-bottom:20px;"
        >
          <div>
            <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px;">
              <span class="dark-label" style="margin-bottom:0;">Start time</span>
              <span style="font-size:22px;font-weight:700;color:#F4EFE2;font-family:'Bricolage Grotesque',sans-serif;letter-spacing:-0.02em;">
                {time_label(@start_minutes)}
              </span>
            </div>
            <form phx-change="set_start">
              <input
                type="range"
                name="value"
                min="420"
                max="1260"
                step="15"
                value={@start_minutes}
                style="width:100%;accent-color:#54B57E;cursor:pointer;"
              />
            </form>
          </div>

          <div>
            <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px;">
              <span class="dark-label" style="margin-bottom:0;">Duration</span>
              <span style="font-size:22px;font-weight:700;color:#F4EFE2;font-family:'Bricolage Grotesque',sans-serif;letter-spacing:-0.02em;">
                {duration_label(@duration_minutes)}
              </span>
            </div>
            <form phx-change="set_duration">
              <input
                type="range"
                name="value"
                min="15"
                max="480"
                step="15"
                value={@duration_minutes}
                style="width:100%;accent-color:#54B57E;cursor:pointer;"
              />
            </form>
          </div>
        </div>

        <%!-- materials & plants --%>
        <div style="margin-bottom:20px;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Materials &amp; plants</span>
            <button
              type="button"
              phx-click="open_materials_sheet"
              ontouchstart=""
              style="display:flex;align-items:center;gap:4px;font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path
                  d="M12 5v14M5 12h14"
                  stroke="currentColor"
                  stroke-width="2.2"
                  stroke-linecap="round"
                />
              </svg>
              Add
            </button>
          </div>
          <div
            :if={@draft_map == %{}}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;"
          >
            No materials added
          </div>
          <div :if={@draft_map != %{}} style="display:flex;flex-direction:column;gap:8px;">
            <div
              :for={{_id, {item, qty}} <- @draft_map}
              style="border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;padding:10px 13px;display:flex;align-items:center;gap:10px;"
            >
              <div style="flex:1;min-width:0;">
                <p style="font-size:13.5px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {catalog_item_title(item)}
                </p>
                <p style="font-size:12px;color:#9A9384;margin-top:1px;">
                  {item.name} · ×{format_qty(qty)}
                </p>
              </div>
              <button
                type="button"
                phx-click="remove_material"
                phx-value-id={item.id}
                style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;flex:0 0 auto;"
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
      </div>

      <%!-- sticky CTA --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:12px 16px;">
        <.glow_button
          valid={not is_nil(@garden) and not is_nil(@category)}
          type="button"
          phx-click="save_adhoc_job"
          phx-throttle="2000"
        >
          {if @timing == :now, do: "Start job →", else: "Log job →"}
        </.glow_button>
      </div>

      <%!-- garden picker sheet --%>
      <div
        :if={@show_garden_picker}
        style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
      >
        <div
          style="position:absolute;inset:0;background:rgba(0,0,0,0.6);"
          phx-click="close_garden_picker"
        >
        </div>
        <div style="position:relative;z-index:10;background:#211E16;border-radius:24px 24px 0 0;padding:20px 16px 32px;max-height:80dvh;display:flex;flex-direction:column;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;flex-shrink:0;">
            <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Pick garden</span>
            <button
              type="button"
              phx-click="close_garden_picker"
              style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
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
          <form phx-change="search_garden" style="margin-bottom:12px;flex-shrink:0;">
            <input
              type="text"
              value={@garden_search}
              name="garden_search"
              phx-debounce="300"
              class="dark-input"
              placeholder="Search…"
            />
          </form>
          <div style="overflow-y:auto;min-height:0;flex:1;display:flex;flex-direction:column;gap:8px;">
            <button
              :for={g <- filtered_gardens(@all_gardens, @garden_search)}
              type="button"
              phx-click="pick_garden"
              phx-value-id={g.id}
              ontouchstart=""
              style={"width:100%;border-radius:14px;border:1.5px solid;background:#16140E;padding:11px 13px;text-align:left;cursor:pointer;#{if @garden && @garden.id == g.id, do: "border-color:#54B57E;", else: "border-color:rgba(52,48,37,0.58);"}"}
            >
              <p style="font-size:13.5px;font-weight:700;color:#F4EFE2;">
                {g.name || "Unnamed site"}
              </p>
              <p :if={g.street} style="font-size:12px;color:#9A9384;margin-top:1px;">{g.street}</p>
            </button>
            <div
              :if={filtered_gardens(@all_gardens, @garden_search) == []}
              style="padding:24px;text-align:center;font-size:13.5px;color:#6E675A;"
            >
              No gardens found
            </div>
          </div>
        </div>
      </div>

      <%!-- materials sheet --%>
      <div
        :if={@show_materials_sheet}
        style="position:fixed;inset:0;z-index:60;display:flex;flex-direction:column;justify-content:flex-end;"
      >
        <div
          style="position:absolute;inset:0;background:rgba(0,0,0,0.6);"
          phx-click="close_materials_sheet"
        >
        </div>
        <div style="position:relative;z-index:10;background:#211E16;border-radius:24px 24px 0 0;padding:20px 16px 32px;max-height:90dvh;display:flex;flex-direction:column;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;flex-shrink:0;">
            <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Add material or plant</span>
            <button
              type="button"
              phx-click="close_materials_sheet"
              ontouchstart=""
              style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
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
          <form phx-change="search_catalog" style="margin-bottom:12px;flex-shrink:0;">
            <input
              type="text"
              value={@catalog_search}
              name="catalog_search"
              phx-debounce="300"
              class="dark-input"
              placeholder="Search catalogue…"
            />
          </form>
          <div style="overflow-y:auto;min-height:0;flex:1;display:flex;flex-direction:column;gap:8px;">
            <div
              :if={@catalog_search == "" and @draft_map == %{}}
              style="padding:20px;text-align:center;font-size:13px;color:#6E675A;"
            >
              Search to add materials
            </div>
            <div
              :if={@catalog_search != "" and @catalog_results == []}
              style="padding:20px;text-align:center;font-size:13px;color:#6E675A;"
            >
              No results
            </div>
            <div
              :for={item <- @catalog_results}
              style={"background:#16140E;border-radius:12px;padding:11px 13px;border:1px solid #{if Map.has_key?(@draft_map, item.id), do: "#54B57E", else: "rgba(52,48,37,0.58)"};"}
            >
              <div style="display:flex;align-items:baseline;justify-content:space-between;gap:8px;">
                <p style="font-size:13.5px;font-weight:600;font-style:italic;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {catalog_item_title(item)}
                </p>
                <span style="font-size:11px;color:#9A9384;flex-shrink:0;">
                  {item.supplier_catalog.supplier.name}
                </span>
              </div>
              <p style="font-size:11px;color:#6E675A;margin-top:2px;">
                {item.name}{if item.format_description, do: " · #{item.format_description}"}
              </p>
              <div
                :if={Map.has_key?(@draft_map, item.id)}
                style="display:flex;align-items:center;gap:4px;margin-top:8px;"
              >
                <button
                  :if={item.min_order_qty && item.min_order_qty > 1}
                  type="button"
                  phx-click="draft_sub_flat"
                  phx-value-id={item.id}
                  ontouchstart=""
                  style={draft_btn_style()}
                >
                  −f
                </button>
                <button
                  type="button"
                  phx-click="draft_sub_one"
                  phx-value-id={item.id}
                  ontouchstart=""
                  style={draft_btn_style()}
                >
                  −1
                </button>
                <div style="min-width:40px;text-align:center;">
                  <span style="font-size:16px;font-weight:700;color:#F4EFE2;">
                    {elem(Map.get(@draft_map, item.id), 1)}
                  </span>
                </div>
                <button
                  type="button"
                  phx-click="draft_add_one"
                  phx-value-id={item.id}
                  ontouchstart=""
                  style={draft_btn_style()}
                >
                  +1
                </button>
                <button
                  :if={item.min_order_qty && item.min_order_qty > 1}
                  type="button"
                  phx-click="draft_add_flat"
                  phx-value-id={item.id}
                  ontouchstart=""
                  style={draft_btn_style()}
                >
                  +f
                </button>
              </div>
              <div
                :if={!Map.has_key?(@draft_map, item.id)}
                style="display:flex;gap:6px;margin-top:8px;"
              >
                <button
                  :if={item.min_order_qty && item.min_order_qty > 1}
                  type="button"
                  phx-click="draft_add_flat"
                  phx-value-id={item.id}
                  ontouchstart=""
                  style={draft_add_btn_style()}
                >
                  + flat
                </button>
                <button
                  type="button"
                  phx-click="draft_add_one"
                  phx-value-id={item.id}
                  ontouchstart=""
                  style={draft_add_btn_style()}
                >
                  + 1
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("open_garden_picker", _params, socket) do
    {:noreply, assign(socket, show_garden_picker: true, garden_search: "")}
  end

  @impl true
  def handle_event("close_garden_picker", _params, socket) do
    {:noreply, assign(socket, show_garden_picker: false)}
  end

  @impl true
  def handle_event("search_garden", %{"garden_search" => q}, socket) do
    {:noreply, assign(socket, :garden_search, q)}
  end

  @impl true
  def handle_event("pick_garden", %{"id" => id}, socket) do
    garden = Enum.find(socket.assigns.all_gardens, &(&1.id == id))
    {:noreply, assign(socket, garden: garden, show_garden_picker: false)}
  end

  @impl true
  def handle_event("set_category", %{"cat" => cat}, socket) do
    {:noreply, assign(socket, :category, String.to_existing_atom(cat))}
  end

  @impl true
  def handle_event("set_timing", %{"timing" => timing}, socket) do
    {:noreply, assign(socket, :timing, String.to_existing_atom(timing))}
  end

  @impl true
  def handle_event("set_start", %{"value" => val}, socket) do
    {:noreply, assign(socket, :start_minutes, String.to_integer(val))}
  end

  @impl true
  def handle_event("set_duration", %{"value" => val}, socket) do
    {:noreply, assign(socket, :duration_minutes, String.to_integer(val))}
  end

  @impl true
  def handle_event("open_materials_sheet", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_materials_sheet, true)
     |> assign(:catalog_search, "")
     |> assign(:catalog_results, [])}
  end

  @impl true
  def handle_event("close_materials_sheet", _params, socket) do
    {:noreply, assign(socket, :show_materials_sheet, false)}
  end

  @impl true
  def handle_event("search_catalog", %{"catalog_search" => q}, socket) do
    q = String.trim(q)
    member = socket.assigns.current_member

    results =
      if String.length(q) >= 2 do
        Inventory.search_supplier_catalog_items!(q,
          actor: member,
          tenant: member.organisation_id,
          load: [supplier_catalog: [:supplier]]
        )
      else
        []
      end

    {:noreply, assign(socket, catalog_search: q, catalog_results: results)}
  end

  @impl true
  def handle_event("draft_add_one", %{"id" => id}, socket) do
    item = find_catalog_result(socket.assigns.catalog_results, id)
    {:noreply, adjust_draft(socket, id, item, +1)}
  end

  @impl true
  def handle_event("draft_add_flat", %{"id" => id}, socket) do
    item = find_catalog_result(socket.assigns.catalog_results, id)
    {:noreply, adjust_draft(socket, id, item, +draft_flat_size(item))}
  end

  @impl true
  def handle_event("draft_sub_one", %{"id" => id}, socket) do
    item = find_catalog_result(socket.assigns.catalog_results, id)
    {:noreply, adjust_draft(socket, id, item, -1)}
  end

  @impl true
  def handle_event("draft_sub_flat", %{"id" => id}, socket) do
    item = find_catalog_result(socket.assigns.catalog_results, id)
    {:noreply, adjust_draft(socket, id, item, -draft_flat_size(item))}
  end

  @impl true
  def handle_event("remove_material", %{"id" => id}, socket) do
    {:noreply, assign(socket, :draft_map, Map.delete(socket.assigns.draft_map, id))}
  end

  @impl true
  def handle_event("save_adhoc_job", _params, socket) do
    member = socket.assigns.current_member
    shift = socket.assigns.active_shift
    opts = [actor: member, tenant: member.organisation_id]

    job_params = %{
      type: :client_work,
      garden_id: socket.assigns.garden.id,
      service_category: socket.assigns.category,
      containing_shift_id: shift.id
    }

    case Work.create_job(job_params, opts) do
      {:ok, job} ->
        write_job_materials(job, socket.assigns.draft_map, opts)

        case socket.assigns.timing do
          :now ->
            log_adhoc_now(job, shift, member, opts)

          :done ->
            log_adhoc_done(
              job,
              shift,
              member,
              socket.assigns.start_minutes,
              socket.assigns.duration_minutes,
              opts
            )
        end

        {:noreply,
         socket
         |> put_flash(:info, "Job added.")
         |> push_navigate(to: ~p"/manage/today", replace: true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create job.")}
    end
  end

  defp log_adhoc_now(job, shift, member, opts) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    event =
      Work.log_job_event!(
        %{
          job_id: job.id,
          timestamp: now,
          data: %{type: :arrival, odometer_km: nil},
          organisation_id: member.organisation_id
        },
        opts
      )

    Enum.each(shift.staff_assignments, fn sa ->
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

    Work.mark_job_in_progress(job, opts)
  end

  defp log_adhoc_done(job, shift, member, start_minutes, duration_minutes, opts) do
    today = Date.utc_today()
    arrival_dt = minutes_to_utc(today, start_minutes)
    departure_dt = minutes_to_utc(today, start_minutes + duration_minutes)

    arrival_event =
      Work.log_job_event!(
        %{
          job_id: job.id,
          timestamp: arrival_dt,
          data: %{type: :arrival, odometer_km: nil},
          organisation_id: member.organisation_id
        },
        opts
      )

    Enum.each(shift.staff_assignments, fn sa ->
      Work.log_job_event_staff(
        %{
          job_event_id: arrival_event.id,
          member_id: sa.member_id,
          man_hour_rate: sa.member.labor_hourly_rate,
          organisation_id: member.organisation_id
        },
        opts
      )
    end)

    departure_event =
      Work.log_job_event!(
        %{
          job_id: job.id,
          timestamp: departure_dt,
          data: %{type: :departure, odometer_km: nil},
          organisation_id: member.organisation_id
        },
        opts
      )

    Enum.each(shift.staff_assignments, fn sa ->
      Work.log_job_event_staff(
        %{
          job_event_id: departure_event.id,
          member_id: sa.member_id,
          man_hour_rate: sa.member.labor_hourly_rate,
          organisation_id: member.organisation_id
        },
        opts
      )
    end)

    Work.complete_job(job, opts)
  end

  defp minutes_to_utc(date, minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    {:ok, naive} = NaiveDateTime.new(date, Time.new!(h, m, 0))
    DateTime.from_naive!(naive, "Etc/UTC")
  end

  defp write_job_materials(_job, draft_map, _opts) when draft_map == %{}, do: :ok

  defp write_job_materials(job, draft_map, opts) do
    Enum.each(draft_map, fn {_id, {item, qty}} ->
      Work.create_job_material(
        %{job_id: job.id, supplier_catalog_item_id: item.id, quantity: qty},
        opts
      )
    end)
  end

  defp adjust_draft(socket, id, item, delta) do
    map = socket.assigns.draft_map

    new_qty =
      case Map.get(map, id) do
        nil -> max(delta, 1)
        {_item, qty} -> Decimal.to_integer(Decimal.round(Decimal.add(qty, Decimal.new(delta)), 0))
      end

    if new_qty <= 0 do
      assign(socket, :draft_map, Map.delete(map, id))
    else
      entry = {item || elem(Map.get(map, id), 0), Decimal.new(new_qty)}
      assign(socket, :draft_map, Map.put(map, id, entry))
    end
  end

  defp find_catalog_result(results, id), do: Enum.find(results, &(&1.id == id))

  defp draft_flat_size(nil), do: 1
  defp draft_flat_size(%{min_order_qty: nil}), do: 1
  defp draft_flat_size(%{min_order_qty: n}), do: n

  defp catalog_item_title(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name
      title -> title
    end
  end

  defp format_qty(qty) do
    d = Decimal.normalize(qty)
    if Decimal.integer?(d), do: Decimal.to_integer(d), else: Decimal.to_string(d)
  end

  defp draft_btn_style,
    do:
      "background:#2B2820;border:1px solid rgba(52,48,37,0.58);border-radius:8px;color:#F4EFE2;font-size:12px;font-weight:600;padding:5px 9px;cursor:pointer;min-width:32px;"

  defp draft_add_btn_style,
    do:
      "background:#2B2820;border:1px solid rgba(84,181,126,0.4);border-radius:8px;color:#54B57E;font-size:12px;font-weight:700;padding:6px 14px;cursor:pointer;"

  defp filtered_gardens(gardens, ""), do: gardens

  defp filtered_gardens(gardens, search) do
    q = String.downcase(search)

    Enum.filter(gardens, fn g ->
      Enum.any?([g.name, g.street], fn f -> f && String.contains?(String.downcase(f), q) end)
    end)
  end

  defp time_label(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    ampm = if h < 12, do: "am", else: "pm"
    h12 = rem(h, 12)
    h12 = if h12 == 0, do: 12, else: h12
    "#{h12}:#{String.pad_leading(to_string(m), 2, "0")} #{ampm}"
  end

  defp duration_label(minutes) when minutes < 60, do: "#{minutes}m"

  defp duration_label(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    if m == 0, do: "#{h}h", else: "#{h}h #{m}m"
  end
end
