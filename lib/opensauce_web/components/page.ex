defmodule OpenSauceWeb.Components.Page do
  @moduledoc """
  Layout primitives for manage views, including the mobile bottom-nav shell.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    router: OpenSauceWeb.Router,
    endpoint: OpenSauceWeb.Endpoint

  alias Phoenix.LiveView.JS

  slot :inner_block, required: true
  attr :class, :string, default: nil

  def page(assigns) do
    ~H"""
    <div class={["space-y-6", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true
  slot :actions
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :class, :string, default: nil

  def section(assigns) do
    ~H"""
    <section class={["space-y-4", @class]}>
      <header
        :if={@title || @description || @actions != []}
        class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
      >
        <div class="space-y-1">
          <h2 :if={@title} class="text-base font-semibold text-stone-900 sm:text-lg">
            {@title}
          </h2>
          <p :if={@description} class="text-sm text-stone-500">
            {@description}
          </p>
        </div>

        <div
          :if={@actions != []}
          class="flex w-full items-center justify-start gap-2 sm:w-auto sm:justify-end"
        >
          {render_slot(@actions)}
        </div>
      </header>

      <div>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  slot :inner_block, required: true
  slot :header
  slot :actions
  slot :footer
  attr :class, :string, default: nil
  attr :padding, :string, default: "p-6"
  attr :full_bleed, :boolean, default: false

  def surface(assigns) do
    assigns =
      assign(
        assigns,
        :content_classes,
        Enum.reject(["flex flex-col gap-4", assigns[:padding]], &is_nil/1)
      )

    ~H"""
    <div class={["rounded-md border border-gray-200 bg-white", @class]}>
      <div class={@content_classes}>
        <div
          :if={@header != [] || @actions != []}
          class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
        >
          <div>{render_slot(@header)}</div>
          <div :if={@actions != []} class="flex items-center gap-2">
            {render_slot(@actions)}
          </div>
        </div>

        <div>
          {render_slot(@inner_block)}
        </div>

        <div
          :if={@footer != []}
          class="flex flex-col gap-2 border-t border-stone-200 pt-4 sm:flex-row sm:items-center sm:justify-between"
        >
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  slot :left, required: true
  slot :right
  attr :gap, :string, default: "gap-6"
  attr :class, :string, default: nil
  attr :left_class, :string, default: "flex-1 space-y-6"
  attr :right_class, :string, default: "space-y-6 lg:w-72"

  def two_column(assigns) do
    ~H"""
    <div class={["flex flex-col lg:flex-row", @gap, @class]}>
      <div class={@left_class}>
        {render_slot(@left)}
      </div>
      <aside :if={@right != []} class={@right_class}>
        {render_slot(@right)}
      </aside>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :columns, :integer, default: 3
  attr :class, :string, default: nil

  def form_grid(assigns) do
    assigns =
      assign(assigns, :grid_class, grid_class(assigns[:columns]))

    ~H"""
    <div class={["grid gap-4", @grid_class, @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :links, :list, required: true
  attr :id, :string, default: nil
  attr :class, :string, default: nil

  def toggle_bar(assigns) do
    ~H"""
    <div class={["bg-stone-200/60 inline-flex items-center justify-center rounded-lg p-1", @class]}>
      <.link
        :for={link <- @links}
        navigate={link.navigate}
        id={link[:id]}
        class={[
          "rounded-md px-3 py-1.5 text-sm font-medium transition",
          "text-stone-600 hover:text-stone-900",
          link[:active] && "bg-white text-stone-900 shadow"
        ]}
        data-active={link[:active]}
      >
        {link.label}
      </.link>
    </div>
    """
  end

  attr :for_id, :string, default: nil
  attr :text, :string, default: nil
  attr :rest, :global, default: %{}

  def filter_reset(assigns) do
    ~H"""
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-md border border-stone-200 px-3 py-2 text-sm font-medium text-stone-600 transition hover:border-stone-300 hover:text-stone-900"
      phx-click={JS.push("reset_filters", target: nil)}
      {@rest}
    >
      <span>{@text || "Reset filters"}</span>
    </button>
    """
  end

  defp grid_class(columns) when columns <= 1, do: "grid-cols-1"
  defp grid_class(2), do: "sm:grid-cols-2"
  defp grid_class(3), do: "sm:grid-cols-2 lg:grid-cols-3"
  defp grid_class(4), do: "sm:grid-cols-2 lg:grid-cols-4"
  defp grid_class(_), do: "sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"

  # -------------------------------------------------------------------------
  # Bottom navigation shell
  # -------------------------------------------------------------------------

  @more_sections [
    %{label: "Inventory", path: "/manage/inventory"},
    %{label: "Engagements", path: "/manage/engagements"},
    %{label: "Venues", path: "/manage/venues"},
    %{label: "Invoices", path: "/manage/invoices"},
    %{label: "Settings", path: "/manage/settings"}
  ]

  @primary_prefixes ["/manage/today", "/manage/jobs", "/manage/customers", "/manage/purchasing"]

  attr :current_path, :string, default: ""

  def bottom_nav(assigns) do
    more_active =
      assigns.current_path != "" and
        not Enum.any?(@primary_prefixes, &String.starts_with?(assigns.current_path, &1))

    assigns = assign(assigns, more_active: more_active, more_sections: @more_sections)

    ~H"""
    <div>
      <%!-- More overflow sheet --%>
      <div
        id="more-backdrop"
        class="hidden fixed inset-0 z-30"
        phx-click={hide_more_sheet()}
        aria-hidden="true"
      />
      <div
        id="more-sheet"
        class="hidden fixed inset-x-0 bottom-14 z-40 bg-white border-t border-stone-200 shadow-lg rounded-t-xl"
        role="dialog"
        aria-label="More navigation"
      >
        <div class="px-4 pt-4 pb-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-stone-400 mb-3">More</p>
          <ul class="space-y-1">
            <li :for={s <- @more_sections}>
              <.link
                navigate={s.path}
                phx-click={hide_more_sheet()}
                class={[
                  "flex items-center justify-between rounded-lg px-3 py-3 text-sm font-medium transition",
                  String.starts_with?(@current_path, s.path) &&
                    "bg-stone-100 text-stone-900",
                  not String.starts_with?(@current_path, s.path) &&
                    "text-stone-600 hover:bg-stone-50 hover:text-stone-900"
                ]}
              >
                {s.label}
                <.chevron_right_icon />
              </.link>
            </li>
          </ul>
          <div class="h-safe-bottom" />
        </div>
      </div>

      <%!-- Bottom nav bar --%>
      <nav
        class="fixed bottom-0 inset-x-0 z-50 bg-white border-t border-stone-200"
        aria-label="Primary navigation"
        style="padding-bottom: env(safe-area-inset-bottom)"
      >
        <div class="flex">
          <.nav_tab
            navigate={~p"/manage/today"}
            label="Today"
            active={String.starts_with?(@current_path, "/manage/today")}
          >
            <:icon><.today_icon /></:icon>
          </.nav_tab>

          <.nav_tab
            navigate={~p"/manage/jobs"}
            label="Jobs"
            active={String.starts_with?(@current_path, "/manage/jobs")}
          >
            <:icon><.jobs_icon /></:icon>
          </.nav_tab>

          <.nav_tab
            navigate={~p"/manage/customers"}
            label="Customers"
            active={
              String.starts_with?(@current_path, "/manage/customers") or
                String.starts_with?(@current_path, "/manage/engagements")
            }
          >
            <:icon><.customers_icon /></:icon>
          </.nav_tab>

          <.nav_tab
            navigate={~p"/manage/purchasing"}
            label="POs"
            active={String.starts_with?(@current_path, "/manage/purchasing")}
          >
            <:icon><.purchasing_icon /></:icon>
          </.nav_tab>

          <button
            id="more-tab"
            type="button"
            class={[
              "flex flex-1 flex-col items-center justify-center gap-1 py-2 min-h-[3.5rem] text-[10px] leading-none font-medium transition",
              @more_active && "text-stone-900",
              not @more_active && "text-stone-400"
            ]}
            phx-click={show_more_sheet()}
            aria-label="More"
          >
            <.more_icon />
            <span>More</span>
          </button>
        </div>
      </nav>
    </div>
    """
  end

  slot :icon, required: true
  attr :navigate, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_tab(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex flex-1 flex-col items-center justify-center gap-1 py-2 min-h-[3.5rem] text-[10px] leading-none font-medium transition",
        @active && "text-stone-900",
        not @active && "text-stone-400 hover:text-stone-600"
      ]}
    >
      {render_slot(@icon)}
      <span>{@label}</span>
    </.link>
    """
  end

  defp show_more_sheet(js \\ %JS{}) do
    js
    |> JS.show(to: "#more-backdrop")
    |> JS.show(to: "#more-sheet")
  end

  defp hide_more_sheet(js \\ %JS{}) do
    js
    |> JS.hide(to: "#more-backdrop")
    |> JS.hide(to: "#more-sheet")
  end

  defp today_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364-6.364l-.707.707M6.343 17.657l-.707.707M17.657 17.657l-.707-.707M6.343 6.343l-.707-.707M12 7a5 5 0 110 10A5 5 0 0112 7z"
      />
    </svg>
    """
  end

  defp jobs_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
    """
  end

  defp customers_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M17 20h5v-1a6 6 0 00-9-5.197M9 20H4v-1a6 6 0 0112 0v1zm3-9a4 4 0 100-8 4 4 0 000 8z"
      />
    </svg>
    """
  end

  defp purchasing_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M7 4h10l1 3H6l1-3zm-1 5h12l1 9H5l1-9zm3 4h4"
      />
    </svg>
    """
  end

  defp more_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M4 6h16M4 12h16M4 18h16"
      />
    </svg>
    """
  end

  defp chevron_right_icon(assigns) do
    ~H"""
    <svg class="h-4 w-4 text-stone-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
    </svg>
    """
  end
end
