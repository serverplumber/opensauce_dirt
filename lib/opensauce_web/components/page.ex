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
    %{label: "Purchasing", path: "/manage/purchasing"},
    %{label: "Inventory", path: "/manage/inventory"},
    %{label: "Venues", path: "/manage/venues"},
    %{label: "Invoices", path: "/manage/invoices"}
  ]

  @primary_prefixes ["/manage/today", "/manage/schedule", "/manage/jobs", "/manage/customers", "/manage/purchasing"]

  attr :current_path, :string, default: ""
  attr :current_user, :any, default: nil
  attr :current_member, :any, default: nil
  attr :memberships, :list, default: []

  def bottom_nav(assigns) do
    more_active =
      assigns.current_path != "" and
        not Enum.any?(@primary_prefixes, &String.starts_with?(assigns.current_path, &1))

    assigns = assign(assigns, more_active: more_active, more_sections: @more_sections)

    ~H"""
    <div>
      <%!-- User sheet --%>
      <div
        id="user-sheet"
        class="hidden fixed inset-0 z-50 flex items-end justify-center"
        role="dialog"
        aria-label="Account"
      >
        <div
          class="absolute inset-0 bg-black/50"
          phx-click={hide_user_sheet()}
          aria-hidden="true"
        />
        <div
          class="relative w-full max-w-lg bg-[#211E16] rounded-t-2xl"
          style="border-top:1.5px solid rgba(52,48,37,0.58);padding-bottom:max(1.5rem,env(safe-area-inset-bottom))"
        >
          <%!-- User header --%>
          <div style="display:flex;align-items:center;gap:12px;padding:18px 18px 14px;">
            <div style={"width:44px;height:44px;border-radius:12px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:18px;letter-spacing:-0.01em;color:#fff;#{user_monogram_gradient(@current_member)}"}>
              {user_monogram_initial(@current_user)}
            </div>
            <div style="flex:1;min-width:0;">
              <div style="font-size:15px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {user_display_name(@current_user)}
              </div>
              <div style="margin-top:2px;font-size:12px;color:#6E675A;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {@current_user && @current_user.email}
              </div>
            </div>
            <button
              type="button"
              phx-click={hide_user_sheet()}
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;flex-shrink:0;"
            >
              <svg width="18" height="18" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <%!-- Org list --%>
          <div :if={length(@memberships) > 1} style="border-top:1px solid rgba(52,48,37,0.58);padding:10px 8px 6px;">
            <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;padding:0 10px 6px;">
              Organisations
            </p>
            <div>
              <% current_org_id = @current_member && @current_member.organisation_id %>
              <a
                :for={m <- @memberships}
                href={if m.organisation_id != current_org_id, do: ~p"/org/pick/#{m.organisation_id}", else: nil}
                style={"display:flex;align-items:center;gap:10px;border-radius:10px;padding:9px 10px;text-decoration:none;#{if m.organisation_id == current_org_id, do: "background:rgba(84,181,126,0.10);", else: ""}"}
              >
                <div style={"width:30px;height:30px;border-radius:8px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:13px;color:#fff;#{org_monogram_gradient(m.role)}"}>
                  {m.organisation.name |> String.trim() |> String.first() |> String.upcase()}
                </div>
                <span style={"flex:1;font-size:13.5px;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;#{if m.organisation_id == current_org_id, do: "color:#54B57E;", else: "color:#F4EFE2;"}"}>
                  {m.organisation.name}
                </span>
                <svg :if={m.organisation_id == current_org_id} width="14" height="14" fill="none" stroke="#54B57E" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/>
                </svg>
                <svg :if={m.organisation_id != current_org_id} width="14" height="14" fill="none" stroke="#6E675A" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
              </a>
            </div>
          </div>

          <%!-- Settings + Sign out --%>
          <div style="border-top:1px solid rgba(52,48,37,0.58);padding:6px 8px 4px;">
            <.link
              navigate={~p"/manage/account"}
              phx-click={hide_user_sheet()}
              style="display:flex;align-items:center;justify-content:space-between;border-radius:10px;padding:11px 10px;text-decoration:none;"
            >
              <span style="font-size:13.5px;font-weight:600;color:#F4EFE2;">Account & profile</span>
              <svg width="14" height="14" fill="none" stroke="#6E675A" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
            </.link>
            <button
              type="button"
              ontouchstart=""
              phx-click={JS.hide(to: "#user-sheet") |> show_sign_out_sheet()}
              style="display:flex;align-items:center;justify-content:space-between;border-radius:10px;padding:11px 10px;width:100%;background:none;border:none;cursor:pointer;"
            >
              <span style="font-size:13.5px;font-weight:600;color:#E87E7E;">Sign out</span>
              <svg width="14" height="14" fill="none" stroke="#E87E7E" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <%!-- Sign-out confirmation sheet --%>
      <div
        id="sign-out-sheet"
        class="hidden fixed inset-0 z-50 flex items-end justify-center"
        role="dialog"
        aria-label="Sign out confirmation"
      >
        <div
          class="absolute inset-0 bg-black/50"
          phx-click={hide_sign_out_sheet()}
          aria-hidden="true"
        />
        <div
          class="relative w-full bg-[#211E16] rounded-t-2xl px-6 pt-6 space-y-4 max-w-lg"
          style="border-top: 1.5px solid rgba(52,48,37,0.58); padding-bottom: max(2.5rem, env(safe-area-inset-bottom))"
        >
          <div class="space-y-1">
            <p class="text-base font-semibold text-[#F4EFE2]">Sign out?</p>
            <p class="text-sm text-[#9A9384]">You'll need a new magic link to sign back in.</p>
          </div>
          <div :if={@current_user}>
            <p class="text-xs text-[#6E675A] truncate">{@current_user.email}</p>
          </div>
          <div class="flex flex-col gap-3 pb-2">
            <.link
              href={~p"/sign-out"}
              method="delete"
              class="leaf-btn flex w-full items-center justify-center rounded-xl px-4 py-3 text-sm font-semibold transition"
            >
              Sign out
            </.link>
            <button
              type="button"
              class="flex w-full items-center justify-center rounded-xl px-4 py-3 text-sm font-medium text-[#9A9384] hover:bg-[#2B2820] hover:text-[#F4EFE2] transition"
              style="border: 1.5px solid rgba(52,48,37,0.58)"
              phx-click={hide_sign_out_sheet()}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>

      <%!-- More overflow sheet --%>
      <div
        id="more-backdrop"
        class="hidden fixed inset-0 z-30"
        phx-click={hide_more_sheet()}
        aria-hidden="true"
      />
      <div
        id="more-sheet"
        class="hidden fixed inset-x-0 bottom-14 z-40 bg-[#211E16] shadow-lg rounded-t-xl"
        style="border-top: 1.5px solid rgba(52,48,37,0.58)"
        role="dialog"
        aria-label="More navigation"
      >
        <div class="px-4 pt-4 pb-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-[#6E675A] mb-3">More</p>
          <ul class="space-y-1">
            <li :for={s <- @more_sections}>
              <.link
                navigate={s.path}
                phx-click={hide_more_sheet()}
                class={[
                  "flex items-center justify-between rounded-lg px-3 py-3 text-sm font-medium transition",
                  String.starts_with?(@current_path, s.path) &&
                    "bg-[rgba(84,181,126,0.14)] text-[#54B57E]",
                  not String.starts_with?(@current_path, s.path) &&
                    "text-[#9A9384] hover:bg-[#2B2820] hover:text-[#F4EFE2]"
                ]}
              >
                {s.label}
                <.chevron_right_icon />
              </.link>
            </li>
          </ul>
          <div :if={@current_user} class="mt-2 pt-2" style="border-top: 1px solid rgba(52,48,37,0.58)">
            <button
              type="button"
              ontouchstart=""
              phx-click={hide_more_sheet() |> show_user_sheet()}
              class="flex w-full items-center gap-3 rounded-lg px-3 py-3 transition hover:bg-[#2B2820]"
            >
              <div style={"width:36px;height:36px;border-radius:10px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:16px;color:#fff;#{user_monogram_gradient(@current_member)}"}>
                {user_monogram_initial(@current_user)}
              </div>
              <div style="flex:1;min-width:0;text-align:left;">
                <div style="font-size:13.5px;font-weight:600;color:#F4EFE2;line-height:1.3;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {user_display_name(@current_user)}
                </div>
                <div style="margin-top:2px;display:flex;align-items:center;gap:6px;">
                  <span style={"font-size:10.5px;font-weight:700;letter-spacing:0.03em;padding:2px 7px;border-radius:999px;#{role_pill_style(@current_member)}"}>
                    {role_label(@current_member)}
                  </span>
                </div>
              </div>
              <.chevron_right_icon />
            </button>
          </div>
          <div class="h-safe-bottom" />
        </div>
      </div>

      <%!-- Bottom nav bar --%>
      <nav
        id="bottom-nav"
        class="fixed bottom-0 inset-x-0 z-50 bg-[#211E16]"
        aria-label="Primary navigation"
        style="border-top: 1.5px solid rgba(52,48,37,0.58); padding-bottom: env(safe-area-inset-bottom)"
      >
        <div class="flex">
          <.nav_tab
            navigate={~p"/manage/today"}
            label="Home"
            active={String.starts_with?(@current_path, "/manage/today")}
          >
            <:icon><.home_icon /></:icon>
          </.nav_tab>

          <.nav_tab
            navigate={~p"/manage/schedule"}
            label="Schedule"
            active={String.starts_with?(@current_path, "/manage/schedule")}
          >
            <:icon><.schedule_icon /></:icon>
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
            label="Clients"
            active={String.starts_with?(@current_path, "/manage/customers")}
          >
            <:icon><.customers_icon /></:icon>
          </.nav_tab>

          <button
            id="more-tab"
            type="button"
            class={[
              "flex flex-1 flex-col items-center justify-center gap-1 py-2 min-h-[3.5rem] text-[10px] leading-none font-medium transition",
              @more_active && "text-[#54B57E]",
              not @more_active && "text-[#6E675A]"
            ]}
            phx-click={toggle_more_sheet()}
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
        @active && "text-[#54B57E]",
        not @active && "text-[#6E675A] hover:text-[#9A9384]"
      ]}
    >
      {render_slot(@icon)}
      <span>{@label}</span>
    </.link>
    """
  end

  defp toggle_more_sheet(js \\ %JS{}) do
    js
    |> JS.hide(to: "#user-sheet")
    |> JS.toggle(to: "#more-backdrop")
    |> JS.toggle(to: "#more-sheet")
    |> JS.toggle_class("!text-[#54B57E]", to: "#more-tab")
  end

  defp hide_more_sheet(js \\ %JS{}) do
    js
    |> JS.hide(to: "#more-backdrop")
    |> JS.hide(to: "#more-sheet")
    |> JS.remove_class("!text-[#54B57E]", to: "#more-tab")
  end

  defp show_user_sheet(js \\ %JS{}) do
    js
    |> JS.show(to: "#user-sheet", display: "flex")
    |> JS.add_class("hidden", to: "#bottom-nav")
  end

  defp hide_user_sheet(js \\ %JS{}) do
    js
    |> JS.hide(to: "#user-sheet")
    |> JS.remove_class("hidden", to: "#bottom-nav")
  end

  defp show_sign_out_sheet(js \\ %JS{}) do
    js
    |> JS.show(to: "#sign-out-sheet", display: "flex")
    |> JS.add_class("hidden", to: "#bottom-nav")
  end

  defp hide_sign_out_sheet(js \\ %JS{}) do
    js
    |> JS.hide(to: "#sign-out-sheet")
    |> JS.remove_class("hidden", to: "#bottom-nav")
  end

  defp home_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M3 12l2-2m0 0l7-7 7 7m-9 9V12h4v7m5-7v7a2 2 0 01-2 2H5a2 2 0 01-2-2v-7"
      />
    </svg>
    """
  end

  defp schedule_icon(assigns) do
    ~H"""
    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.75"
        d="M9 14h.01M12 14h.01M15 14h.01"
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

  defp user_display_name(nil), do: ""

  defp user_display_name(user) do
    first = user.first_name
    last = user.last_name

    cond do
      first && last -> "#{first} #{last}"
      first -> first
      true -> user.email |> to_string() |> String.split("@") |> hd() |> String.capitalize()
    end
  end

  defp user_monogram_initial(nil), do: "?"
  defp user_monogram_initial(%{initials: initials}) when is_binary(initials), do: initials

  defp user_monogram_initial(user) do
    user.email |> to_string() |> String.split("@") |> hd() |> String.first() |> String.upcase()
  end

  defp user_monogram_gradient(%{role: role}) when role in [:owner, :manager],
    do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"

  defp user_monogram_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"

  defp org_monogram_gradient(:owner), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp org_monogram_gradient(:manager), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp org_monogram_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"

  defp role_pill_style(%{role: role}) when role in [:owner, :manager],
    do: "background:rgba(219,146,88,0.16);color:#DB9258;"

  defp role_pill_style(_), do: "background:rgba(84,181,126,0.14);color:#54B57E;"

  defp role_label(%{role: :owner}), do: "Owner"
  defp role_label(%{role: :manager}), do: "Manager"
  defp role_label(_), do: "Field crew"

  defp chevron_right_icon(assigns) do
    ~H"""
    <svg class="h-4 w-4 text-stone-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
    </svg>
    """
  end
end
