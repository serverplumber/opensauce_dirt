defmodule OpenSauceWeb.JobLive.New do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauce.Inventory
  alias OpenSauce.Orders

  @addressable_categories [:installation, :pruning, :consultation, :design, :opening, :winterization]

  @service_categories [
    {:installation, "Install"},
    {:delivery, "Delivery"},
    {:pruning, "Pruning"},
    {:consultation, "Consult"},
    {:design, "Design"},
    {:opening, "Opening"},
    {:winterization, "Winterize"},
    {:nursery_run, "Nursery run"},
    {:other, "Other"}
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
     |> assign(:scheduled_for, "")
     |> assign(:duration_h, "")
     |> assign(:duration_m, "")
     |> assign(:notes, "")
     |> assign(:step1_error, nil)
     |> assign(:save_error, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "New Job")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto pb-4">
      <%!-- Step 1 --%>
      <div :if={@step == 1} class="px-4 space-y-5 pt-2 pb-40">
        <%!-- Back --%>
        <div class="flex items-center justify-between">
          <.link navigate={~p"/manage/jobs"} class="text-stone-400 hover:text-stone-600 p-1 -ml-1">
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </.link>
          <span class="text-xs font-medium text-stone-400">Step 1 of 2</span>
        </div>

        <%!-- Type segmented control --%>
        <div>
          <p class="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2">Type of work</p>
          <div class="flex rounded-xl border border-stone-200 bg-stone-100 p-1 gap-1">
            <button
              :for={{val, label} <- [{:client_work, "Client"}, {:shift, "Shift"}, {:internal_work, "Internal"}]}
              type="button"
              phx-click="set_type"
              phx-value-type={val}
              class={[
                "flex-1 rounded-lg py-2 text-sm font-medium transition",
                if(@job_type == val,
                  do: "bg-white text-stone-900 shadow-sm",
                  else: "text-stone-500 hover:text-stone-700"
                )
              ]}
            >
              {label}
            </button>
          </div>
        </div>

        <%!-- Client work fields --%>
        <div :if={@job_type == :client_work} class="space-y-5">
          <%!-- Engagement --%>
          <div>
            <div class="flex items-center justify-between mb-2">
              <p class="text-xs font-semibold uppercase tracking-wider text-stone-400">Engagement</p>
              <button
                type="button"
                phx-click="toggle_engagement"
                class={[
                  "relative inline-flex h-5 w-9 items-center rounded-full transition-colors focus:outline-none",
                  if(@engagement_enabled, do: "bg-amber-500", else: "bg-stone-200")
                ]}
                role="switch"
                aria-checked={to_string(@engagement_enabled)}
              >
                <span class={[
                  "inline-block h-3.5 w-3.5 rounded-full bg-white shadow transition-transform",
                  if(@engagement_enabled, do: "translate-x-4", else: "translate-x-1")
                ]} />
              </button>
            </div>
            <div :if={@engagement_enabled}>
              <div :if={@engagement} class="rounded-xl border-2 border-amber-400 bg-amber-50 px-3 py-3 flex items-center gap-3">
                <div class="w-9 h-9 rounded-lg border-2 border-amber-400 flex items-center justify-center text-xl font-bold text-amber-600 font-mono shrink-0">
                  {engagement_initial(@engagement)}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-stone-900 truncate">{engagement_title(@engagement)}</p>
                  <p class="text-xs text-stone-500 mt-0.5">{engagement_subtitle(@engagement)}</p>
                </div>
                <button
                  type="button"
                  phx-click="open_engagement_sheet"
                  class="text-xs font-medium text-amber-600 hover:text-amber-800 shrink-0"
                >
                  change
                </button>
              </div>
              <div :if={is_nil(@engagement)}>
                <button
                  type="button"
                  phx-click="open_engagement_sheet"
                  class="w-full rounded-xl border border-dashed border-stone-300 bg-white px-3 py-3 text-sm text-stone-400 hover:border-stone-400 hover:text-stone-600 text-left"
                >
                  Pick an engagement…
                </button>
              </div>
            </div>
          </div>

          <%!-- Garden / site --%>
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2">Garden / site</p>
            <div :if={@garden}>
              <div class={[
                "rounded-xl border px-3 py-3 flex items-center justify-between",
                if(garden_from_engagement?(@garden, @engagement),
                  do: "border-stone-200 bg-stone-50",
                  else: "border-amber-400 bg-amber-50"
                )
              ]}>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-stone-900">{@garden.name || "Unnamed site"}</p>
                  <p :if={@garden.street} class="text-xs text-stone-500 mt-0.5">{@garden.street}</p>
                  <p :if={garden_from_engagement?(@garden, @engagement)} class="text-xs text-stone-400 mt-0.5">from engagement</p>
                </div>
                <.icon :if={garden_from_engagement?(@garden, @engagement)} name="hero-check-circle" class="h-5 w-5 text-amber-500 shrink-0" />
                <button
                  :if={not garden_from_engagement?(@garden, @engagement)}
                  type="button"
                  phx-click="open_garden_sheet"
                  class="text-xs font-medium text-amber-600 hover:text-amber-800 shrink-0"
                >
                  change
                </button>
              </div>
            </div>
            <div :if={is_nil(@garden)}>
              <button
                type="button"
                phx-click="open_garden_sheet"
                class="w-full rounded-xl border border-dashed border-stone-300 bg-white px-3 py-3 text-sm text-stone-400 hover:border-stone-400 hover:text-stone-600 text-left"
              >
                Pick a garden…
              </button>
            </div>
          </div>

          <%!-- Service category --%>
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2">Service category</p>
            <form phx-change="set_category">
              <select
                name="service_category"
                class="w-full rounded-xl border border-stone-200 bg-white px-3 py-2.5 text-sm text-stone-900 focus:border-amber-400 focus:outline-none appearance-none"
              >
                <option value="">— pick one —</option>
                <option
                  :for={{cat, label} <- @service_categories}
                  value={cat}
                  selected={@service_category == cat}
                >
                  {label}
                </option>
              </select>
            </form>
          </div>
        </div>

        <%!-- Internal work fields --%>
        <div :if={@job_type == :internal_work}>
          <p class="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2">Account code</p>
          <div class="flex gap-2">
            <button
              :for={{code, label} <- [{:production, "Production"}, {:maintenance, "Maintenance"}]}
              type="button"
              phx-click="set_account_code"
              phx-value-code={code}
              class={[
                "flex-1 rounded-xl border py-3 text-sm font-medium transition",
                if(@account_code == code,
                  do: "bg-stone-900 text-white border-stone-900",
                  else: "bg-white text-stone-600 border-stone-200 hover:border-stone-400"
                )
              ]}
            >
              {label}
            </button>
          </div>
        </div>

        <%!-- Materials --%>
        <div :if={@job_type != :shift}>
          <div class="flex items-center justify-between mb-2">
            <p class="text-xs font-semibold uppercase tracking-wider text-stone-400">Materials &amp; plants</p>
            <button
              type="button"
              phx-click="open_materials_sheet"
              class="flex items-center gap-1 text-xs font-medium text-amber-600 hover:text-amber-800"
            >
              <.icon name="hero-plus" class="h-3.5 w-3.5" /> Add
            </button>
          </div>
          <div :if={@draft_materials == []} class="rounded-xl border border-dashed border-stone-200 bg-white px-3 py-3 text-sm text-stone-400 text-center">
            No materials added
          </div>
          <div :if={@draft_materials != []} class="space-y-2">
            <div
              :for={{{item, qty}, idx} <- Enum.with_index(@draft_materials)}
              class="rounded-xl border border-stone-200 bg-white px-3 py-2.5 flex items-center gap-3"
            >
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-stone-900 truncate">{catalog_item_title(item)}</p>
                <p class="text-xs text-stone-500">{item.name} · qty {format_qty(qty)}</p>
              </div>
              <button
                type="button"
                phx-click="remove_material"
                phx-value-index={idx}
                class="text-stone-300 hover:text-red-500 transition shrink-0"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        <%!-- Next button --%>
        <div class="fixed bottom-16 left-0 right-0 bg-white border-t border-stone-200 px-4 py-3 space-y-2">
          <p :if={@step1_error} class="text-xs text-red-600 text-center">{@step1_error}</p>
          <button
            type="button"
            phx-click="next"
            class="w-full rounded-xl bg-amber-500 py-3.5 text-sm font-semibold text-white hover:bg-amber-600 active:bg-amber-700 transition"
          >
            Next: schedule →
          </button>
        </div>
      </div>

      <%!-- Step 2 --%>
      <div :if={@step == 2} class="px-4 space-y-5 pt-2 pb-40">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <button type="button" phx-click="back" class="text-stone-400 hover:text-stone-600 p-1 -ml-1">
            <.icon name="hero-arrow-left" class="h-5 w-5" />
          </button>
          <span class="text-xs font-medium text-stone-400">Step 2 of 2</span>
        </div>

        <%!-- Step 1 summary pill --%>
        <div class="rounded-xl border border-stone-100 bg-stone-50 px-3 py-2.5 flex items-center gap-2 flex-wrap">
          <span :if={@service_category} class="rounded-full bg-stone-200 px-2.5 py-0.5 text-xs font-semibold text-stone-700">
            {category_label(@service_category)}
          </span>
          <span :if={@account_code} class="rounded-full bg-stone-200 px-2.5 py-0.5 text-xs font-semibold text-stone-700">
            {account_code_label(@account_code)}
          </span>
          <span :if={@job_type == :shift} class="rounded-full bg-stone-200 px-2.5 py-0.5 text-xs font-semibold text-stone-700">
            Shift
          </span>
          <span :if={@garden && @garden.customer} class="text-xs text-stone-500">
            {customer_display(@garden.customer)}
          </span>
          <span :if={@garden} class="text-xs text-stone-500">{@garden.name || "Unnamed site"}</span>
        </div>

        <form phx-change="update_step2" class="space-y-5">
          <%!-- When? --%>
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2">When?</p>
            <div class="flex gap-3">
              <div class="flex-1">
                <input
                  type="date"
                  name="scheduled_for"
                  value={@scheduled_for}
                  class="w-full rounded-xl border border-stone-200 bg-white px-3 py-2.5 text-sm text-stone-900 focus:border-amber-400 focus:outline-none"
                />
              </div>
              <div class="flex items-center gap-1">
                <input
                  type="number"
                  name="duration_h"
                  value={@duration_h}
                  min="0"
                  max="23"
                  class="w-14 rounded-xl border border-stone-200 bg-white px-2 py-2.5 text-sm text-stone-900 text-center focus:border-amber-400 focus:outline-none"
                />
                <span class="text-xs text-stone-400">h</span>
                <input
                  type="number"
                  name="duration_m"
                  value={@duration_m}
                  min="0"
                  max="59"
                  class="w-14 rounded-xl border border-stone-200 bg-white px-2 py-2.5 text-sm text-stone-900 text-center focus:border-amber-400 focus:outline-none"
                />
                <span class="text-xs text-stone-400">m</span>
              </div>
            </div>
          </div>

          <%!-- Notes --%>
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2">Notes</p>
            <textarea
              name="notes"
              rows="3"
              maxlength="2000"
              class="w-full rounded-xl border border-stone-200 bg-white px-3 py-2.5 text-sm text-stone-900 focus:border-amber-400 focus:outline-none resize-none"
            >{@notes}</textarea>
          </div>
        </form>

        <p :if={@save_error} class="rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-sm text-red-700">
          {@save_error}
        </p>

        <%!-- Sticky create --%>
        <div class="fixed bottom-16 left-0 right-0 bg-white border-t border-stone-200 px-4 py-3">
          <button
            type="button"
            phx-click="save"
            phx-throttle="2000"
            class="w-full rounded-xl bg-amber-500 py-3.5 text-sm font-semibold text-white hover:bg-amber-600 active:bg-amber-700 transition"
          >
            Create job
          </button>
        </div>
      </div>

      <%!-- Engagement sheet --%>
      <div
        :if={@show_engagement_sheet}
        id="engagement-sheet"
        class="fixed inset-0 z-40 flex flex-col justify-end"
        phx-window-keydown="close_engagement_sheet"
        phx-key="Escape"
      >
        <div class="absolute inset-0 bg-black/40" phx-click="close_engagement_sheet"></div>
        <div class="relative z-10 bg-white rounded-t-2xl px-4 pt-4 pb-8 max-h-[80dvh] flex flex-col">
          <div class="flex items-center justify-between mb-3">
            <p class="text-sm font-semibold text-stone-900">Pick engagement</p>
            <button type="button" phx-click="close_engagement_sheet" class="text-stone-400 hover:text-stone-600">
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
          <input
            type="text"
            value={@engagement_search}
            phx-change="search_engagement"
            name="engagement_search"
            phx-debounce="200"
            class="rounded-xl border border-stone-200 px-3 py-2.5 text-sm focus:border-amber-400 focus:outline-none mb-3"
          />
          <div class="overflow-y-auto space-y-2">
            <button
              :for={eng <- filtered_engagements(@all_engagements, @engagement_search)}
              type="button"
              phx-click="pick_engagement"
              phx-value-id={eng.id}
              class={[
                "w-full rounded-xl border px-3 py-2.5 text-left flex items-center gap-3 transition",
                if(@engagement && @engagement.id == eng.id,
                  do: "border-amber-400 bg-amber-50",
                  else: "border-stone-200 bg-white hover:border-stone-300"
                )
              ]}
            >
              <div class="w-8 h-8 rounded-lg border border-stone-300 flex items-center justify-center text-base font-bold text-stone-600 font-mono shrink-0">
                {engagement_initial(eng)}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-stone-900 truncate">{engagement_title(eng)}</p>
                <p class="text-xs text-stone-400">{engagement_subtitle(eng)}</p>
              </div>
            </button>
            <div :if={filtered_engagements(@all_engagements, @engagement_search) == []} class="py-6 text-center text-sm text-stone-400">
              No engagements found
            </div>
          </div>
        </div>
      </div>

      <%!-- Garden sheet (when no engagement) --%>
      <div
        :if={@show_garden_sheet}
        id="garden-sheet"
        class="fixed inset-0 z-40 flex flex-col justify-end"
        phx-window-keydown="close_garden_sheet"
        phx-key="Escape"
      >
        <div class="absolute inset-0 bg-black/40" phx-click="close_garden_sheet"></div>
        <div class="relative z-10 bg-white rounded-t-2xl px-4 pt-4 pb-8 max-h-[80dvh] flex flex-col">
          <div class="flex items-center justify-between mb-3">
            <p class="text-sm font-semibold text-stone-900">Pick garden</p>
            <button type="button" phx-click="close_garden_sheet" class="text-stone-400 hover:text-stone-600">
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
          <input
            type="text"
            value={@garden_search}
            phx-change="search_garden"
            name="garden_search"
            phx-debounce="200"
            class="rounded-xl border border-stone-200 px-3 py-2.5 text-sm focus:border-amber-400 focus:outline-none mb-3"
          />
          <div class="overflow-y-auto space-y-2">
            <button
              :for={garden <- filtered_gardens(@all_gardens, @garden_search)}
              type="button"
              phx-click="pick_garden"
              phx-value-id={garden.id}
              class={[
                "w-full rounded-xl border px-3 py-2.5 text-left transition",
                if(@garden && @garden.id == garden.id,
                  do: "border-amber-400 bg-amber-50",
                  else: "border-stone-200 bg-white hover:border-stone-300"
                )
              ]}
            >
              <p class="text-sm font-medium text-stone-900">{garden.name || "Unnamed site"}</p>
              <p :if={garden.street} class="text-xs text-stone-400 mt-0.5">{garden.street}</p>
            </button>
            <div :if={filtered_gardens(@all_gardens, @garden_search) == []} class="py-6 text-center text-sm text-stone-400">
              No gardens found
            </div>
          </div>
        </div>
      </div>

      <%!-- Materials sheet --%>
      <div
        :if={@show_materials_sheet}
        id="materials-sheet"
        class="fixed inset-0 z-40 flex flex-col justify-end"
        phx-window-keydown="close_materials_sheet"
        phx-key="Escape"
      >
        <div class="absolute inset-0 bg-black/40" phx-click="close_materials_sheet"></div>
        <div class="relative z-10 bg-white rounded-t-2xl px-4 pt-4 pb-8 max-h-[90dvh] flex flex-col gap-3">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-stone-900">Add material or plant</p>
            <button type="button" phx-click="close_materials_sheet" class="text-stone-400 hover:text-stone-600">
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>

          <div class="relative">
            <input
              type="text"
              value={@catalog_search}
              phx-change="search_catalog"
              name="catalog_search"
              phx-debounce="300"
              class="w-full rounded-xl border border-stone-200 px-3 py-2.5 text-sm focus:border-amber-400 focus:outline-none"
            />
            <div
              :if={@catalog_results != []}
              class="absolute z-10 mt-1 w-full rounded-xl border border-stone-200 bg-white shadow-lg overflow-hidden"
            >
              <button
                :for={item <- @catalog_results}
                type="button"
                phx-click="pick_catalog_item"
                phx-value-id={item.id}
                class="flex w-full flex-col px-3 py-2.5 text-left text-sm hover:bg-stone-50 border-b border-stone-100 last:border-0"
              >
                <div class="flex items-baseline justify-between gap-2">
                  <span class="font-medium italic text-stone-800">{catalog_item_title(item)}</span>
                  <span class="shrink-0 text-xs text-stone-400">{item.supplier_catalog.supplier.name}</span>
                </div>
                <span class="text-xs text-stone-400">
                  {item.name}{if item.format_description, do: " · #{item.format_description}"}
                </span>
              </button>
            </div>
          </div>

          <div :if={@selected_catalog_item} class="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5">
            <p class="text-sm font-medium italic text-amber-900">{catalog_item_title(@selected_catalog_item)}</p>
            <p class="text-xs text-amber-700 mt-0.5">{@selected_catalog_item.name}</p>
          </div>

          <div class="flex items-center gap-3">
            <label class="text-xs font-medium text-stone-500 shrink-0">Qty</label>
            <input
              type="number"
              name="add_qty"
              value={@add_qty}
              min="0.01"
              step="0.01"
              phx-change="set_add_qty"
              class="w-24 rounded-xl border border-stone-200 px-3 py-2 text-sm text-stone-900 text-center focus:border-amber-400 focus:outline-none"
            />
            <button
              type="button"
              phx-click="add_material"
              disabled={is_nil(@selected_catalog_item)}
              class="flex-1 rounded-xl bg-amber-500 py-2 text-sm font-semibold text-white hover:bg-amber-600 disabled:opacity-40 disabled:cursor-not-allowed transition"
            >
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

    {:noreply, socket}
  end

  def handle_event("open_engagement_sheet", _params, socket) do
    {:noreply, assign(socket, show_engagement_sheet: true, engagement_search: "")}
  end

  def handle_event("close_engagement_sheet", _params, socket) do
    {:noreply, assign(socket, show_engagement_sheet: false)}
  end

  def handle_event("search_engagement", %{"engagement_search" => q}, socket) do
    {:noreply, assign(socket, :engagement_search, q)}
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
     |> assign(:show_engagement_sheet, false)}
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

    {:noreply, socket}
  end

  def handle_event("set_category", %{"service_category" => ""}, socket) do
    {:noreply, assign(socket, service_category: nil, step1_error: nil)}
  end

  def handle_event("set_category", %{"service_category" => cat}, socket) do
    {:noreply, assign(socket, service_category: String.to_existing_atom(cat), step1_error: nil)}
  end

  def handle_event("set_account_code", %{"code" => code}, socket) do
    {:noreply, assign(socket, :account_code, String.to_existing_atom(code))}
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
     |> assign(:show_garden_sheet, false)}
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
    case validate_step1(socket.assigns) do
      :ok ->
        {:noreply, assign(socket, step: 2, step1_error: nil, save_error: nil)}

      {:error, msg} ->
        {:noreply, assign(socket, :step1_error, msg)}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: 1)}
  end

  def handle_event("update_step2", params, socket) do
    {:noreply,
     socket
     |> assign(:scheduled_for, Map.get(params, "scheduled_for", socket.assigns.scheduled_for))
     |> assign(:duration_h, Map.get(params, "duration_h", socket.assigns.duration_h))
     |> assign(:duration_m, Map.get(params, "duration_m", socket.assigns.duration_m))
     |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))}
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
         |> push_navigate(to: ~p"/manage/jobs")}

      {:error, %Ash.Error.Invalid{} = err} ->
        msg = err.errors |> Enum.map(& &1.message) |> Enum.join(", ")
        {:noreply, assign(socket, :save_error, msg)}

      {:error, _} ->
        {:noreply, assign(socket, :save_error, "Could not create job.")}
    end
  end

  defp validate_step1(%{job_type: :shift}), do: :ok

  defp validate_step1(%{job_type: :internal_work, account_code: nil}),
    do: {:error, "Select an account code"}

  defp validate_step1(%{job_type: :internal_work}), do: :ok

  defp validate_step1(%{job_type: :client_work, service_category: nil}),
    do: {:error, "Select a service category"}

  defp validate_step1(%{job_type: :client_work, service_category: cat, garden: nil})
       when cat in @addressable_categories,
       do: {:error, "A garden is required for #{Phoenix.Naming.humanize(cat)} jobs"}

  defp validate_step1(%{job_type: :client_work}), do: :ok

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
      case assigns.scheduled_for do
        "" -> params
        d -> Map.put(params, :scheduled_for, Date.from_iso8601!(d))
      end

    params =
      case duration_minutes(assigns.duration_h, assigns.duration_m) do
        nil -> params
        mins -> Map.put(params, :duration_estimate, mins)
      end

    params
  end

  defp duration_minutes("", ""), do: nil
  defp duration_minutes("", m), do: duration_minutes("0", m)
  defp duration_minutes(h, ""), do: duration_minutes(h, "0")

  defp duration_minutes(h, m) do
    with {h_int, ""} <- Integer.parse(h),
         {m_int, ""} <- Integer.parse(m),
         mins = h_int * 60 + m_int,
         true <- mins > 0 do
      mins
    else
      _ -> nil
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

  defp filtered_engagements(engagements, ""), do: engagements

  defp filtered_engagements(engagements, q) do
    q = String.downcase(q)

    Enum.filter(engagements, fn eng ->
      customer_match =
        eng.customer &&
          (downcase_contains(eng.customer.first_name, q) or
             downcase_contains(eng.customer.last_name, q) or
             downcase_contains(eng.customer.company_name_nickname, q))

      garden_match = eng.garden && downcase_contains(eng.garden.name, q)

      customer_match || garden_match
    end)
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

  defp engagement_title(%{customer: nil} = e), do: "Engagement #{String.slice(e.id, 0, 8)}"

  defp engagement_title(%{customer: c, garden: nil}), do: customer_display(c)

  defp engagement_title(%{customer: c, garden: g}),
    do: "#{customer_display(c)} · #{g.name || "Unnamed site"}"

  defp engagement_subtitle(%{garden: nil}), do: "No site"

  defp engagement_subtitle(%{garden: g}) do
    [g.street, g.city] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
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
