defmodule OpenSauceWeb.JobLive.New do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauce.Orders

  @service_categories [
    {:installation, "Install"},
    {:delivery, "Delivery"},
    {:pruning, "Pruning"},
    {:consultation, "Consult"},
    {:design, "Design"},
    {:opening, "Opening"},
    {:winterization, "Winterize"},
    {:maintenance, "Maintenance"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member
    all_engagements = load_engagements(member)
    all_gardens = load_gardens(member)

    {:ok,
     socket
     |> assign(:step, 1)
     |> assign(:service_categories, @service_categories)
     |> assign(:job_type, :client_work)
     |> assign(:engagement_enabled, true)
     |> assign(:engagement, nil)
     |> assign(:garden, nil)
     |> assign(:service_category, nil)
     |> assign(:account_code, nil)
     |> assign(:all_engagements, all_engagements)
     |> assign(:filtered_engagements, all_engagements)
     |> assign(:all_gardens, all_gardens)
     |> assign(:engagement_search, "")
     |> assign(:show_engagement_sheet, false)
     |> assign(:show_garden_sheet, false)
     |> assign(:garden_search, "")
     |> assign(:show_materials_sheet, false)
     |> assign(:draft_materials, [])
     |> assign(:catalog_search, "")
     |> assign(:catalog_results, [])
     |> assign(:selected_catalog_item, nil)
     |> assign(:add_qty, "1")
     |> assign(:due_by_week, "")
     |> assign(:notes, "")
     |> assign(:service_error, nil)
     |> assign(:garden_error, nil)
     |> assign(:save_error, nil)
     |> assign(:back_to, ~p"/manage/jobs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    garden_id = Map.get(params, "garden_id")
    customer_ref = Map.get(params, "customer_ref")
    engagement_id = Map.get(params, "engagement_id")

    back_to =
      if customer_ref,
        do: ~p"/manage/customers/#{customer_ref}",
        else: ~p"/manage/jobs"

    socket =
      if customer_ref do
        customer_engagements =
          Enum.filter(socket.assigns.all_engagements, fn eng ->
            eng.customer && eng.customer.reference == customer_ref
          end)

        socket
        |> assign(:all_engagements, customer_engagements)
        |> assign(:filtered_engagements, customer_engagements)
        |> assign(:engagement_enabled, customer_engagements != [])
      else
        socket
      end

    socket =
      cond do
        engagement_id ->
          eng = Enum.find(socket.assigns.all_engagements, &(&1.id == engagement_id))
          garden = eng && eng.garden

          socket
          |> assign(:engagement, eng)
          |> assign(:garden, garden)
          |> assign(:engagement_enabled, true)

        garden_id ->
          garden = Enum.find(socket.assigns.all_gardens, &(&1.id == garden_id))
          assign(socket, :garden, garden)

        true ->
          socket
      end

    {:noreply,
     socket
     |> assign(:page_title, "New Job")
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:back_to, back_to)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- ── Step 1 ─────────────────────────────────────────────── --%>
      <div :if={@step == 1} style="padding:0 16px 160px;">

        <%!-- header --%>
        <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 2px 14px;">
          <.link navigate={@back_to} style="color:#6E675A;line-height:0;padding:4px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </.link>
          <span style="font-size:12px;font-weight:600;color:#6E675A;">Step 1 of 2</span>
        </div>

        <%!-- type segmented control --%>
        <div style="margin-bottom:16px;display:flex;gap:4px;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:13px;padding:4px;">
          <button
            :for={{val, label} <- [{:client_work, "Client"}, {:shift, "Shift"}, {:internal_work, "Internal"}]}
            type="button"
            phx-click="set_type"
            phx-value-type={val}
            class={["seg-tab", @job_type == val && "seg-tab--on"]}
          >
            {label}
          </button>
        </div>

        <%!-- client work fields --%>
        <div :if={@job_type == :client_work} style="display:flex;flex-direction:column;gap:14px;">

          <%!-- engagement --%>
          <div>
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">
              <span class="dark-label" style="margin-bottom:0;">Engagement</span>
              <button
                type="button"
                phx-click="toggle_engagement"
                role="switch"
                aria-checked={to_string(@engagement_enabled)}
                style={"position:relative;display:inline-flex;width:36px;height:20px;border-radius:999px;border:none;cursor:pointer;transition:background .12s ease;#{if @engagement_enabled, do: "background:#54B57E;", else: "background:rgba(52,48,37,0.8);"}"}
                ontouchstart=""
              >
                <span style={"display:inline-block;width:14px;height:14px;border-radius:50%;background:#F4EFE2;box-shadow:0 1px 2px rgba(0,0,0,0.4);position:absolute;top:3px;transition:left .12s ease;#{if @engagement_enabled, do: "left:19px;", else: "left:3px;"}"}></span>
              </button>
            </div>
            <div :if={@engagement_enabled}>
              <div :if={@engagement} style="border-radius:14px;border:1.5px solid #54B57E;background:rgba(84,181,126,0.10);padding:11px 13px;display:flex;align-items:center;gap:12px;">
                <div style="width:36px;height:36px;border-radius:10px;border:1.5px solid #54B57E;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:18px;color:#54B57E;flex:0 0 auto;">
                  {engagement_initial(@engagement)}
                </div>
                <div style="flex:1;min-width:0;">
                  <p style="font-size:14px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{engagement_title(@engagement)}</p>
                  <p style="font-size:12px;color:#9A9384;margin-top:2px;">{engagement_subtitle(@engagement)}</p>
                </div>
                <button type="button" phx-click="open_engagement_sheet" style="font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;flex:0 0 auto;">change</button>
              </div>
              <button :if={is_nil(@engagement)} type="button" phx-click="open_engagement_sheet"
                style="width:100%;border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);background:transparent;padding:9px 13px;font-size:13.5px;color:#6E675A;text-align:left;cursor:pointer;"
                ontouchstart="">
                Pick an engagement…
              </button>
            </div>
          </div>

          <%!-- garden / site --%>
          <div>
            <span class="dark-label">Garden / site</span>
            <div :if={@garden} style={"border-radius:14px;border:1.5px solid;padding:11px 13px;display:flex;align-items:center;justify-content:space-between;gap:12px;#{if garden_from_engagement?(@garden, @engagement), do: "border-color:rgba(52,48,37,0.58);background:#211E16;", else: "border-color:#54B57E;background:rgba(84,181,126,0.10);"}"}>
              <div style="flex:1;min-width:0;">
                <p style="font-size:14px;font-weight:700;color:#F4EFE2;">{@garden.name || "Unnamed site"}</p>
                <p :if={@garden.street} style="font-size:12px;color:#9A9384;margin-top:2px;">{@garden.street}</p>
                <p :if={garden_from_engagement?(@garden, @engagement)} style="font-size:11.5px;color:#6E675A;margin-top:2px;">from engagement</p>
              </div>
              <svg :if={garden_from_engagement?(@garden, @engagement)} width="18" height="18" viewBox="0 0 24 24" fill="none" style="color:#54B57E;flex:0 0 auto;">
                <path d="M20 6L9 17l-5-5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <button :if={not garden_from_engagement?(@garden, @engagement)} type="button" phx-click="open_garden_sheet"
                style="font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;flex:0 0 auto;">
                change
              </button>
            </div>
            <button :if={is_nil(@garden)} type="button" phx-click="open_garden_sheet"
              style="width:100%;border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);background:transparent;padding:9px 13px;font-size:13.5px;color:#6E675A;text-align:left;cursor:pointer;"
              ontouchstart="">
              Pick a garden…
            </button>
            <span :if={@garden_error} class="dark-field-error">{@garden_error}</span>
          </div>

          <%!-- service category --%>
          <div>
            <label class="dark-label" for="service_category_select">Service</label>
            <form phx-change="set_category">
              <select name="service_category" id="service_category_select" class="dark-select">
                <option value="">— pick one —</option>
                <option :for={{cat, label} <- @service_categories} value={cat} selected={@service_category == cat}>{label}</option>
              </select>
            </form>
            <span :if={@service_error} class="dark-field-error">{@service_error}</span>
          </div>

        </div>

        <%!-- internal work fields --%>
        <div :if={@job_type == :internal_work}>
          <span class="dark-label">Account code</span>
          <div style="display:flex;gap:8px;">
            <button
              :for={{code, label} <- [{:production, "Production"}, {:maintenance, "Maintenance"}]}
              type="button"
              phx-click="set_account_code"
              phx-value-code={code}
              ontouchstart=""
              style={"flex:1;border-radius:12px;border:1.5px solid;padding:12px;font-size:13.5px;font-weight:700;cursor:pointer;transition:background .12s ease,color .12s ease,border-color .12s ease;#{if @account_code == code, do: "background:#54B57E;color:#0C1F15;border-color:#54B57E;", else: "background:#211E16;color:#9A9384;border-color:rgba(52,48,37,0.58);"}"}
            >
              {label}
            </button>
          </div>
          <span :if={@service_error} class="dark-field-error">{@service_error}</span>
        </div>

        <%!-- materials --%>
        <div :if={@job_type != :shift} style="margin-top:20px;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <span class="dark-label" style="margin-bottom:0;">Materials &amp; plants</span>
            <button type="button" phx-click="open_materials_sheet"
              style="display:flex;align-items:center;gap:4px;font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
              Add
            </button>
          </div>
          <div :if={@draft_materials == []}
            style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
            No materials added
          </div>
          <div :if={@draft_materials != []} style="display:flex;flex-direction:column;gap:8px;">
            <div :for={{{item, qty}, idx} <- Enum.with_index(@draft_materials)}
              style="border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;padding:10px 13px;display:flex;align-items:center;gap:10px;">
              <div style="flex:1;min-width:0;">
                <p style="font-size:13.5px;font-weight:600;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{catalog_item_title(item)}</p>
                <p style="font-size:12px;color:#9A9384;margin-top:1px;">{item.name} · qty {format_qty(qty)}</p>
              </div>
              <button type="button" phx-click="remove_material" phx-value-index={idx}
                style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;flex:0 0 auto;">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none"><path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
              </button>
            </div>
          </div>
        </div>

        <%!-- sticky next bar --%>
        <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:12px 16px;">
          <.glow_button valid={step1_can_proceed?(@job_type, @service_category, @account_code, @garden)} type="button" phx-click="next">
            Next: due date →
          </.glow_button>
        </div>

      </div>

      <%!-- ── Step 2 ─────────────────────────────────────────────── --%>
      <div :if={@step == 2} style="padding:0 16px 160px;">

        <%!-- header --%>
        <div style="display:flex;align-items:center;justify-content:space-between;padding:14px 2px 22px;">
          <button type="button" phx-click="back" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
          <span style="font-size:12px;font-weight:600;color:#6E675A;">Step 2 of 2</span>
        </div>

        <%!-- step 1 summary chips --%>
        <div style="border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;padding:10px 13px;display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:24px;">
          <span :if={@service_category} style="border-radius:999px;background:rgba(84,181,126,0.14);padding:3px 10px;font-size:11.5px;font-weight:700;color:#6BCB93;">{category_label(@service_category)}</span>
          <span :if={@account_code} style="border-radius:999px;background:rgba(84,181,126,0.14);padding:3px 10px;font-size:11.5px;font-weight:700;color:#6BCB93;">{account_code_label(@account_code)}</span>
          <span :if={@job_type == :shift} style="border-radius:999px;background:rgba(84,181,126,0.14);padding:3px 10px;font-size:11.5px;font-weight:700;color:#6BCB93;">Shift</span>
          <span :if={@garden} style="font-size:12.5px;color:#9A9384;">{@garden.name || "Unnamed site"}</span>
        </div>

        <form phx-change="update_step2" style="display:flex;flex-direction:column;gap:20px;">
          <div>
            <label class="dark-label">Due by</label>
            <input type="week" name="due_by_week" value={@due_by_week} class="dark-input" />
            <p :if={@due_by_week != ""} style="font-size:12px;color:#9A9384;margin-top:6px;">
              Week of {week_label(@due_by_week)}
            </p>
          </div>

          <div>
            <label class="dark-label">Notes</label>
            <textarea name="notes" rows="3" maxlength="2000" class="dark-textarea">{@notes}</textarea>
          </div>
        </form>

        <p :if={@save_error}
          style="margin-top:16px;border-radius:12px;border:1.5px solid rgba(232,126,126,0.3);background:rgba(232,126,126,0.08);padding:10px 13px;font-size:13px;color:#E87E7E;">
          {@save_error}
        </p>

        <%!-- sticky schedule bar --%>
        <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:12px 16px;">
          <.glow_button valid={true} type="button" phx-click="save" phx-throttle="2000">
            Create job
          </.glow_button>
        </div>

      </div>

      <%!-- ── Engagement sheet ───────────────────────────────────── --%>
      <div :if={@show_engagement_sheet}
        style="position:fixed;inset:0;z-index:40;display:flex;flex-direction:column;justify-content:flex-end;"
        phx-window-keydown="close_engagement_sheet" phx-key="Escape">
        <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);" phx-click="close_engagement_sheet"></div>
        <div style="position:relative;z-index:10;background:#211E16;border-radius:24px 24px 0 0;padding:20px 16px 32px;max-height:80dvh;display:flex;flex-direction:column;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;">
            <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Pick engagement</span>
            <button type="button" phx-click="close_engagement_sheet" style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
            </button>
          </div>
          <form phx-change="search_engagement" style="margin-bottom:12px;flex-shrink:0;">
            <input type="text" value={@engagement_search} name="engagement_search"
              phx-debounce="300" class="dark-input" placeholder="Search…" />
          </form>
          <div style="overflow-y:auto;min-height:0;flex:1;display:flex;flex-direction:column;gap:8px;">
            <button :for={eng <- @filtered_engagements}
              type="button" phx-click="pick_engagement" phx-value-id={eng.id}
              ontouchstart=""
              style={"width:100%;border-radius:14px;border:1.5px solid;background:#16140E;padding:11px 13px;text-align:left;display:flex;align-items:center;gap:12px;cursor:pointer;#{if @engagement && @engagement.id == eng.id, do: "border-color:#54B57E;", else: "border-color:rgba(52,48,37,0.58);"}"}>
              <div style={"width:32px;height:32px;border-radius:9px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:15px;#{if @engagement && @engagement.id == eng.id, do: "background:rgba(84,181,126,0.14);color:#54B57E;border:1.5px solid #54B57E;", else: "background:rgba(52,48,37,0.5);color:#9A9384;border:1.5px solid rgba(52,48,37,0.58);"}"}>
                {engagement_initial(eng)}
              </div>
              <div style="flex:1;min-width:0;">
                <p style="font-size:13.5px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{engagement_title(eng)}</p>
                <p style="font-size:12px;color:#9A9384;margin-top:1px;">{engagement_subtitle(eng)}</p>
              </div>
            </button>
            <div :if={@filtered_engagements == []}
              style="padding:24px;text-align:center;font-size:13.5px;color:#6E675A;">
              No engagements found
            </div>
          </div>
        </div>
      </div>

      <%!-- ── Garden sheet ────────────────────────────────────────── --%>
      <div :if={@show_garden_sheet}
        style="position:fixed;inset:0;z-index:40;display:flex;flex-direction:column;justify-content:flex-end;"
        phx-window-keydown="close_garden_sheet" phx-key="Escape">
        <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);" phx-click="close_garden_sheet"></div>
        <div style="position:relative;z-index:10;background:#211E16;border-radius:24px 24px 0 0;padding:20px 16px 32px;max-height:80dvh;display:flex;flex-direction:column;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;">
            <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Pick garden</span>
            <button type="button" phx-click="close_garden_sheet" style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
            </button>
          </div>
          <form phx-change="search_garden" style="margin-bottom:12px;flex-shrink:0;">
            <input type="text" value={@garden_search} name="garden_search"
              phx-debounce="300" class="dark-input" placeholder="Search…" />
          </form>
          <div style="overflow-y:auto;min-height:0;flex:1;display:flex;flex-direction:column;gap:8px;">
            <button :for={garden <- filtered_gardens(@all_gardens, @garden_search)}
              type="button" phx-click="pick_garden" phx-value-id={garden.id}
              ontouchstart=""
              style={"width:100%;border-radius:14px;border:1.5px solid;background:#16140E;padding:11px 13px;text-align:left;cursor:pointer;#{if @garden && @garden.id == garden.id, do: "border-color:#54B57E;", else: "border-color:rgba(52,48,37,0.58);"}"}>
              <p style="font-size:13.5px;font-weight:700;color:#F4EFE2;">{garden.name || "Unnamed site"}</p>
              <p :if={garden.street} style="font-size:12px;color:#9A9384;margin-top:1px;">{garden.street}</p>
            </button>
            <div :if={filtered_gardens(@all_gardens, @garden_search) == []}
              style="padding:24px;text-align:center;font-size:13.5px;color:#6E675A;">
              No gardens found
            </div>
          </div>
        </div>
      </div>

      <%!-- ── Materials sheet ───────────────────────────────────── --%>
      <div :if={@show_materials_sheet}
        style="position:fixed;inset:0;z-index:40;display:flex;flex-direction:column;justify-content:flex-end;"
        phx-window-keydown="close_materials_sheet" phx-key="Escape">
        <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);" phx-click="close_materials_sheet"></div>
        <div style="position:relative;z-index:10;background:#211E16;border-radius:24px 24px 0 0;padding:20px 16px 32px;max-height:90dvh;display:flex;flex-direction:column;gap:14px;">
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <span style="font-size:15px;font-weight:700;color:#F4EFE2;">Add material or plant</span>
            <button type="button" phx-click="close_materials_sheet" style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
            </button>
          </div>

          <div style="position:relative;">
            <input type="text" value={@catalog_search} phx-change="search_catalog" name="catalog_search"
              phx-debounce="300" class="dark-input" placeholder="Search catalogue…" />
            <div :if={@catalog_results != []}
              style="position:absolute;z-index:10;top:calc(100% + 4px);width:100%;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;box-shadow:0 8px 24px rgba(0,0,0,0.5);overflow:hidden;">
              <button :for={item <- @catalog_results}
                type="button" phx-click="pick_catalog_item" phx-value-id={item.id}
                ontouchstart=""
                style="display:flex;flex-direction:column;width:100%;padding:10px 13px;text-align:left;border:none;background:transparent;border-bottom:1px solid rgba(52,48,37,0.4);cursor:pointer;">
                <div style="display:flex;align-items:baseline;justify-content:space-between;gap:8px;">
                  <span style="font-size:13.5px;font-weight:600;font-style:italic;color:#F4EFE2;">{catalog_item_title(item)}</span>
                  <span style="font-size:11.5px;color:#9A9384;white-space:nowrap;">{item.supplier_catalog.supplier.name}</span>
                </div>
                <span style="font-size:12px;color:#9A9384;margin-top:2px;">
                  {item.name}{if item.format_description, do: " · #{item.format_description}"}
                </span>
              </button>
            </div>
          </div>

          <div :if={@selected_catalog_item}
            style="border-radius:12px;border:1.5px solid rgba(84,181,126,0.4);background:rgba(84,181,126,0.08);padding:10px 13px;">
            <p style="font-size:13.5px;font-weight:600;font-style:italic;color:#6BCB93;">{catalog_item_title(@selected_catalog_item)}</p>
            <p style="font-size:12px;color:#9A9384;margin-top:2px;">{@selected_catalog_item.name}</p>
          </div>

          <div style="display:flex;align-items:center;gap:10px;">
            <span style="font-size:12px;font-weight:600;color:#6E675A;white-space:nowrap;">Qty</span>
            <input type="number" name="add_qty" value={@add_qty} min="0.01" step="0.01" phx-change="set_add_qty"
              class="dark-input" style="width:80px;text-align:center;" />
            <button type="button" phx-click="add_material" disabled={is_nil(@selected_catalog_item)}
              ontouchstart=""
              style={"flex:1;border-radius:12px;padding:11px;font-size:13.5px;font-weight:700;border:none;cursor:pointer;background:#54B57E;color:#0C1F15;transition:opacity .12s ease;#{if is_nil(@selected_catalog_item), do: "opacity:0.4;cursor:not-allowed;", else: "opacity:1;"}"}>
              Add to job
            </button>
          </div>
        </div>
      </div>

    </div>
    """
  end

  @impl true
  def handle_event("set_type", %{"type" => type}, socket) do
    job_type = String.to_existing_atom(type)

    socket =
      socket
      |> assign(:job_type, job_type)
      |> assign(:service_category, nil)
      |> assign(:account_code, nil)

    socket =
      case job_type do
        :shift -> assign(socket, garden: nil, engagement: nil, engagement_enabled: false)
        _ -> socket
      end

    {:noreply, assign(socket, service_error: nil, garden_error: nil)}
  end

  def handle_event("open_engagement_sheet", _params, socket) do
    {:noreply, assign(socket, show_engagement_sheet: true, engagement_search: "")}
  end

  def handle_event("close_engagement_sheet", _params, socket) do
    {:noreply, assign(socket, show_engagement_sheet: false)}
  end

  def handle_event("search_engagement", %{"engagement_search" => q}, socket) do
    q = String.trim(q)
    member = socket.assigns.current_member

    engagements =
      if String.length(q) >= 2 do
        CRM.search_engagements!(q,
          actor: member,
          tenant: member.organisation_id,
          load: [garden: [:customer], customer: []]
        )
        |> scope_to_base(socket.assigns.all_engagements)
      else
        socket.assigns.all_engagements
      end

    {:noreply,
     socket
     |> assign(:engagement_search, q)
     |> assign(:filtered_engagements, engagements)}
  end

  def handle_event("pick_engagement", %{"id" => id}, socket) do
    eng = Enum.find(socket.assigns.all_engagements, &(&1.id == id))

    garden =
      case eng do
        %{garden: g} when not is_nil(g) -> g
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(:engagement, eng)
     |> assign(:garden, garden)
     |> assign(:show_engagement_sheet, false)
     |> assign(:service_error, nil)
     |> assign(:garden_error, nil)}
  end

  def handle_event("toggle_engagement", _params, socket) do
    enabled = !socket.assigns.engagement_enabled

    socket =
      if enabled do
        assign(socket, :engagement_enabled, true)
      else
        socket
        |> assign(:engagement_enabled, false)
        |> assign(:engagement, nil)
        |> assign(:garden, nil)
      end

    {:noreply, assign(socket, service_error: nil, garden_error: nil)}
  end

  def handle_event("set_category", %{"service_category" => ""}, socket) do
    {:noreply, assign(socket, service_category: nil, service_error: nil)}
  end

  def handle_event("set_category", %{"service_category" => cat}, socket) do
    {:noreply, assign(socket, service_category: String.to_existing_atom(cat), service_error: nil)}
  end

  def handle_event("set_account_code", %{"code" => code}, socket) do
    {:noreply, assign(socket, account_code: String.to_existing_atom(code), service_error: nil)}
  end

  def handle_event("open_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: true, garden_search: "")}
  end

  def handle_event("close_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: false)}
  end

  def handle_event("search_garden", %{"garden_search" => q}, socket) do
    {:noreply, assign(socket, :garden_search, q)}
  end

  def handle_event("pick_garden", %{"id" => id}, socket) do
    garden = Enum.find(socket.assigns.all_gardens, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:garden, garden)
     |> assign(:show_garden_sheet, false)
     |> assign(:garden_error, nil)}
  end

  def handle_event("open_materials_sheet", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_materials_sheet, true)
     |> assign(:catalog_search, "")
     |> assign(:catalog_results, [])
     |> assign(:selected_catalog_item, nil)
     |> assign(:add_qty, "1")}
  end

  def handle_event("close_materials_sheet", _params, socket) do
    {:noreply, assign(socket, show_materials_sheet: false)}
  end

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

    {:noreply, assign(socket, catalog_search: q, catalog_results: results, selected_catalog_item: nil)}
  end

  def handle_event("pick_catalog_item", %{"id" => id}, socket) do
    member = socket.assigns.current_member

    item =
      Ash.get!(Inventory.SupplierCatalogItem, id,
        actor: member,
        tenant: member.organisation_id,
        load: [supplier_catalog: [:supplier]]
      )

    {:noreply,
     socket
     |> assign(:selected_catalog_item, item)
     |> assign(:catalog_results, [])
     |> assign(:catalog_search, "")}
  end

  def handle_event("set_add_qty", %{"add_qty" => qty}, socket) do
    {:noreply, assign(socket, :add_qty, qty)}
  end

  def handle_event("add_material", _params, socket) do
    item = socket.assigns.selected_catalog_item

    if is_nil(item) do
      {:noreply, socket}
    else
      qty =
        case Decimal.parse(socket.assigns.add_qty) do
          {d, ""} -> d
          _ -> Decimal.new(1)
        end

      draft = socket.assigns.draft_materials ++ [{item, qty}]

      {:noreply,
       socket
       |> assign(:draft_materials, draft)
       |> assign(:selected_catalog_item, nil)
       |> assign(:add_qty, "1")
       |> assign(:catalog_search, "")
       |> assign(:catalog_results, [])}
    end
  end

  def handle_event("remove_material", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    draft = List.delete_at(socket.assigns.draft_materials, idx)
    {:noreply, assign(socket, :draft_materials, draft)}
  end

  def handle_event("next", _params, socket) do
    {service_error, garden_error} = step1_errors(socket.assigns)

    if is_nil(service_error) and is_nil(garden_error) do
      {:noreply, assign(socket, step: 2, service_error: nil, garden_error: nil, save_error: nil)}
    else
      {:noreply, assign(socket, service_error: service_error, garden_error: garden_error)}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: 1)}
  end

  def handle_event("update_step2", params, socket) do
    {:noreply,
     socket
     |> assign(:due_by_week, Map.get(params, "due_by_week", socket.assigns.due_by_week))
     |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))
     |> assign(:save_error, nil)}
  end

  def handle_event("save", _params, socket) do
    member = socket.assigns.current_member

    params = build_job_params(socket.assigns)

    case Orders.create_job(params, actor: member, tenant: member.organisation_id) do
      {:ok, job} ->
        write_job_materials(job, socket.assigns.draft_materials, member)

        {:noreply,
         socket
         |> put_flash(:info, "Job created")
         |> push_navigate(to: socket.assigns.back_to)}

      {:error, %Ash.Error.Invalid{} = err} ->
        msg = err.errors |> Enum.map(& &1.message) |> Enum.join(", ")
        {:noreply, assign(socket, :save_error, msg)}

      {:error, _} ->
        {:noreply, assign(socket, :save_error, "Could not create job.")}
    end
  end

  defp step1_can_proceed?(:shift, _cat, _code, _garden), do: true
  defp step1_can_proceed?(:internal_work, _cat, code, _garden), do: not is_nil(code)
  defp step1_can_proceed?(:client_work, cat, _code, garden), do: not is_nil(cat) and not is_nil(garden)

  defp step1_errors(%{job_type: :shift}), do: {nil, nil}

  defp step1_errors(%{job_type: :internal_work, account_code: nil}),
    do: {"Select an account code", nil}

  defp step1_errors(%{job_type: :internal_work}), do: {nil, nil}

  defp step1_errors(%{job_type: :client_work} = a) do
    service_error = if is_nil(a.service_category), do: "Select a service", else: nil
    garden_error = if is_nil(a.garden), do: "Select a garden", else: nil
    {service_error, garden_error}
  end

  defp build_job_params(assigns) do
    params = %{type: assigns.job_type, notes: assigns.notes}

    params =
      case assigns.service_category do
        nil -> params
        cat -> Map.put(params, :service_category, cat)
      end

    params =
      case assigns.account_code do
        nil -> params
        code -> Map.put(params, :account_code, code)
      end

    params =
      case assigns.engagement do
        nil -> params
        eng -> Map.put(params, :engagement_id, eng.id)
      end

    params =
      case assigns.garden do
        nil -> params
        g -> Map.put(params, :garden_id, g.id)
      end

    params =
      case week_last_day(assigns.due_by_week) do
        nil -> params
        date -> Map.put(params, :due_by, date)
      end

    params
  end

  defp week_last_day(""), do: nil

  defp week_last_day(week_str) do
    case Regex.run(~r/^(\d{4})-W(\d{2})$/, week_str) do
      [_, year_s, week_s] ->
        year = String.to_integer(year_s)
        week = String.to_integer(week_s)
        jan4 = Date.new!(year, 1, 4)
        monday_wk1 = Date.add(jan4, -(Date.day_of_week(jan4) - 1))
        Date.add(monday_wk1, (week - 1) * 7 + 6)

      _ ->
        nil
    end
  end

  defp week_label(week_str) do
    case week_last_day(week_str) do
      nil -> ""
      sunday -> Calendar.strftime(sunday, "%d %b %Y")
    end
  end

  defp write_job_materials(_job, [], _member), do: :ok

  defp write_job_materials(job, draft_materials, member) do
    Enum.each(draft_materials, fn {item, qty} ->
      Orders.create_job_material(
        %{job_id: job.id, supplier_catalog_item_id: item.id, quantity: qty},
        actor: member,
        tenant: member.organisation_id
      )
    end)
  end

  defp load_engagements(member) do
    CRM.list_engagements!(
      actor: member,
      tenant: member.organisation_id,
      load: [garden: [:customer], customer: []]
    )
  rescue
    _ -> []
  end

  defp load_gardens(member) do
    CRM.list_gardens!(actor: member, tenant: member.organisation_id, load: [:customer])
  rescue
    _ -> []
  end

  defp scope_to_base(results, base) do
    base_ids = MapSet.new(base, & &1.id)
    Enum.filter(results, &MapSet.member?(base_ids, &1.id))
  end

  defp filtered_gardens(gardens, ""), do: gardens

  defp filtered_gardens(gardens, search) do
    q = String.downcase(search)
    Enum.filter(gardens, &downcase_contains(&1.name, q))
  end

  defp downcase_contains(nil, _q), do: false
  defp downcase_contains(str, q), do: String.contains?(String.downcase(str), q)

  defp garden_from_engagement?(garden, engagement) do
    not is_nil(engagement) and not is_nil(engagement.garden) and
      engagement.garden.id == garden.id
  end

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

  defp engagement_initial(%{customer: nil}), do: "?"

  defp engagement_initial(%{customer: c}) do
    name = c.company_name_nickname || c.first_name || "?"
    String.first(name) |> String.upcase()
  end

  defp engagement_title(%{customer: nil, scope_title: t}) when is_binary(t), do: t
  defp engagement_title(%{customer: nil} = e), do: "Engagement #{String.slice(e.id, 0, 8)}"

  defp engagement_title(%{customer: c, scope_title: t}) when is_binary(t),
    do: "#{customer_display(c)} · #{t}"

  defp engagement_title(%{customer: c}), do: customer_display(c)

  defp engagement_subtitle(%{garden: nil}), do: "No site"

  defp engagement_subtitle(%{garden: g}) do
    [g.name, g.street] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")
  end

  defp customer_display(c) do
    c.company_name_nickname || "#{c.first_name} #{c.last_name}"
  end

  defp category_label(cat) do
    Enum.find_value(@service_categories, &if(elem(&1, 0) == cat, do: elem(&1, 1)))
  end

  defp account_code_label(:production), do: "Production"
  defp account_code_label(:maintenance), do: "Maintenance"
end
