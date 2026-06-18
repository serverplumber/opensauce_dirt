# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.Components.Core do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: OpenSauce.Gettext

  import OpenSauceWeb.HtmlHelpers

  alias Phoenix.HTML.FormField
  alias Phoenix.LiveView.JS

  @doc """
  Renders a keyboard key element.

  ## Examples

      <.kbd>Ctrl</.kbd>
      <.kbd>⌘</.kbd>

  ## Attributes

    * `:class` - Additional CSS classes to apply to the `<kbd>` element.
    * `:rest` - Any additional HTML attributes.

  """
  attr :class, :string, default: nil
  attr :goto_event, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def kbd(assigns) do
    ~H"""
    <kbd
      class={[
        "inline-block whitespace-nowrap rounded border border-stone-400 bg-stone-100 text-stone-700",
        "px-1 py-0.5 text-xs leading-none",
        "max-w-full truncate",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </kbd>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  ## Attributes

    * `:id` - Required. The ID of the modal.
    * `:show` - Optional. Whether to show the modal immediately (default: false).
    * `:on_cancel` - Optional. JS commands to execute when modal is cancelled.
    * `:title` - Optional. The title of the modal.
    * `:description` - Optional. A description for the modal, displayed below the title.
    * `:max_width` - Optional. Maximum width class for the modal (default: "max-w-lg").
    * `:class` - Optional. Additional classes to apply to the modal container.

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :max_width, :string, default: "max-w-3xl"
  attr :fullscreen, :boolean, default: false
  attr :class, :string, default: nil
  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
      aria-labelledby={if @title, do: "#{@id}-title"}
      aria-describedby={if @description, do: "#{@id}-description"}
    >
      <div
        id={"#{@id}-bg"}
        class="bg-stone-900/50 fixed inset-0 transition-opacity print:hidden"
        aria-hidden="true"
      />
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true" tabindex="0">
        <div class="flex min-h-full items-center justify-center">
          <div class={[
            if(@fullscreen,
              do: "fixed inset-0 z-50 h-full w-full max-w-none p-0",
              else: "left-[50%] top-[50%] translate-x-[-50%] translate-y-[-50%] fixed z-50 w-full p-4"
            ),
            not @fullscreen && @max_width
          ]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class={[
                if(@fullscreen,
                  do:
                    "relative hidden bg-[#16140E] transition print:m-0 print:border-0 print:shadow-none",
                  else:
                    "ring-[rgba(52,48,37,0.58)] relative hidden rounded-2xl bg-[#211E16] shadow-lg ring-1 transition"
                ),
                "duration-200 data-[state=closed]:animate-out data-[state=open]:animate-in",
                "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
                not @fullscreen && "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
                not @fullscreen &&
                  "data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%]",
                not @fullscreen &&
                  "data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%]",
                @class
              ]}
            >
              <button
                type="button"
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                class="absolute top-4 right-4 rounded-sm p-1 text-[#6E675A] opacity-70 transition-opacity hover:opacity-100 hover:text-[#9A9384] focus:outline-none focus:ring-2 focus:ring-[#54B57E] focus:ring-offset-2 focus:ring-offset-[#211E16] print:hidden"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark-solid" class="h-5 w-5" />
              </button>

              <div class="flex flex-col p-6">
                <div :if={@title || @description} class="mb-4 space-y-1.5">
                  <h2
                    :if={@title}
                    id={"#{@id}-title"}
                    class="font-['Bricolage_Grotesque',sans-serif] text-lg font-bold leading-none tracking-tight text-[#F4EFE2]"
                  >
                    {@title}
                  </h2>
                  <p :if={@description} id={"#{@id}-description"} class="text-sm text-[#9A9384]">
                    {@description}
                  </p>
                </div>

                <div
                  id={"#{@id}-content"}
                  class={[
                    @fullscreen && "h-[calc(100vh-3.5rem)] overflow-auto",
                    not @fullscreen &&
                      "max-h-[calc(100vh-10rem)] overflow-y-auto sm:max-h-none sm:overflow-visible",
                    "py-1"
                  ]}
                >
                  {render_slot(@inner_block)}
                </div>

                <div
                  :if={@footer != []}
                  class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
                >
                  {render_slot(@footer)}
                </div>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a dark bottom-sheet drawer with a search input and a scrollable slot for list items.

  ## Examples

      <.bottom_sheet title="Pick garden" on_cancel={JS.push("close_garden_sheet")}
        search_value={@garden_search} search_name="garden_search" search_event="search_garden">
        <button :for={g <- @gardens} phx-click="pick_garden" phx-value-id={g.id}>…</button>
      </.bottom_sheet>
  """
  attr :title, :string, required: true
  attr :on_cancel, :string, required: true
  attr :search_value, :string, default: ""
  attr :search_name, :string, default: "search"
  attr :search_event, :string, default: "search"
  attr :search_placeholder, :string, default: "Search…"
  slot :inner_block, required: true

  def bottom_sheet(assigns) do
    ~H"""
    <div
      style="position:fixed;inset:0;z-index:40;display:flex;flex-direction:column;justify-content:flex-end;"
      phx-window-keydown={@on_cancel}
      phx-key="Escape"
    >
      <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);" phx-click={@on_cancel}></div>
      <div style="position:relative;z-index:10;background:#211E16;border-radius:24px 24px 0 0;padding:20px 16px 32px;max-height:80dvh;display:flex;flex-direction:column;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;">
          <span style="font-size:15px;font-weight:700;color:#F4EFE2;">{@title}</span>
          <button type="button" phx-click={@on_cancel} style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;" ontouchstart="">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </button>
        </div>
        <form phx-change={@search_event} style="margin-bottom:12px;flex-shrink:0;">
          <input
            type="text"
            value={@search_value}
            name={@search_name}
            phx-debounce="300"
            class="dark-input"
            placeholder={@search_placeholder}
          />
        </form>
        <div style="overflow-y:auto;min-height:0;flex:1;display:flex;flex-direction:column;gap:8px;">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      style={
        "position:fixed;bottom:86px;left:16px;right:16px;z-index:70;" <>
          "background:#211E16;border-radius:14px;" <>
          "border:1.5px solid #{if @kind == :info, do: "rgba(84,181,126,0.35)", else: "rgba(232,126,126,0.35)"};" <>
          "padding:12px 44px 12px 48px;" <>
          "box-shadow:0 8px 32px rgba(0,0,0,0.5);" <>
          "font-family:'Hanken Grotesk',system-ui,sans-serif;" <>
          "cursor:pointer;"
      }
      {@rest}
    >
      <%!-- accent bar --%>
      <div style={
        "position:absolute;left:16px;top:50%;transform:translateY(-50%);" <>
          "width:3px;height:60%;border-radius:2px;" <>
          "background:#{if @kind == :info, do: "#54B57E", else: "#E87E7E"};"
      }>
      </div>
      <%!-- title (connection errors only) --%>
      <p
        :if={@title}
        style={"font-size:13px;font-weight:700;color:#{if @kind == :info, do: "#6BCB93", else: "#E87E7E"};margin-bottom:2px;"}
      >
        {@title}
      </p>
      <%!-- message --%>
      <p style="font-size:13.5px;font-weight:600;color:#F4EFE2;line-height:1.4;">{msg}</p>
      <%!-- dismiss --%>
      <button
        type="button"
        style="position:absolute;top:50%;right:12px;transform:translateY(-50%);background:none;border:none;cursor:pointer;color:#6E675A;line-height:0;padding:4px;"
        aria-label={gettext("close")}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
          <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button variant={:primary}>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
      <.button expanding={true}>Full Width & Height Button!</.button>
      <.button size={:sm}>Small Button</button>
      <.button size={:lg}>Large Button</button>
      <.button variant={:danger}>Danger Button</button>
      <.button variant={:outline}>Outline Button</button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  # For full width/height
  attr :expanding, :boolean, default: false
  attr :size, :atom, default: :base, values: [:sm, :base, :lg]

  attr :variant, :atom,
    default: :default,
    values: [:default, :secondary, :danger, :outline, :primary]

  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        button_base_classes(),
        button_focus_classes(),
        button_variant_classes(@variant),
        if(@expanding, do: "h-full w-full", else: button_size_classes(@size)),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_variant_classes(:primary), do: "bg-indigo-600 text-white border border-indigo-600 shadow-xs
       hover:bg-indigo-500 active:bg-indigo-700
       focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500/50 focus-visible:ring-offset-2
       disabled:opacity-50 disabled:pointer-events-none"

  defp button_variant_classes(:default),
    do: "bg-stone-200/50 border border-stone-300 shadow-xs hover:bg-stone-200 hover:text-gray-800"

  defp button_variant_classes(:danger), do: "bg-rose-50 text-rose-500 hover:bg-rose-100 border border-rose-300 shadow-xs"

  defp button_variant_classes(:outline),
    do: "bg-transparent text-stone-700 border border-stone-300 shadow-xs hover:bg-stone-100"

  defp button_variant_classes(:secondary), do: button_variant_classes(:default)

  defp button_variant_classes(:ghost),
    do: "bg-transparent text-stone-600 hover:bg-stone-100 hover:text-stone-900 border-none shadow-none"

  defp button_size_classes(:xs), do: "h-5 px-2 py-0 text-xs"
  defp button_size_classes(:sm), do: "h-7 px-3 py-1 text-xs"
  defp button_size_classes(:base), do: "h-9 px-4 py-2"
  defp button_size_classes(:lg), do: "h-11 px-5 py-3 text-base"

  defp button_base_classes,
    do: "cursor-pointer inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium"

  defp button_focus_classes,
    do:
      "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-stone-300 disabled:pointer-events-none disabled:opacity-50"

  # Main Tabs Container
  slot :tab, required: true do
    attr :label, :string, required: true
    attr :path, :string, required: true
    attr :selected?, :boolean, required: true
  end

  attr :id, :string, required: true
  attr :class, :string, default: nil

  def tabs(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <.tabs_nav>
        <:tab :for={tab <- @tab}>
          <.tab_link label={tab.label} path={tab.path} selected?={tab.selected?} />
        </:tab>
      </.tabs_nav>
      <.tabs_content>
        <div :for={tab <- @tab} :if={tab.selected?} class="relative w-full">
          {render_slot(tab)}
        </div>
      </.tabs_content>
    </div>
    """
  end

  @doc """
  Renders a simple horizontal stepper.

  Attributes:
  - `:steps` - list of step labels in order
  - `:current` - current step as string or atom matching one of the labels (case-insensitive)
  - `:goto_event` - optional LiveView event to emit when clicking a prior step
  """
  attr :steps, :list, required: true
  attr :current, :string, required: true
  attr :class, :string, default: nil
  attr :goto_event, :string, default: nil

  def stepper(assigns) do
    ~H"""
    <div class={["mb-4 flex items-center gap-3", @class]}>
      <% current_idx =
        Enum.find_index(@steps, fn s ->
          String.downcase(to_string(s)) == String.downcase(to_string(@current))
        end) || 0 %>
      <%= for {step, idx} <- Enum.with_index(@steps) do %>
        <% current? = String.downcase(to_string(@current)) == String.downcase(to_string(step)) %>
        <div class="flex items-center gap-2">
          <div class={[
            "flex h-6 w-6 items-center justify-center rounded-full text-xs",
            current? && "bg-stone-800 text-white",
            not current? && "bg-stone-200 text-stone-700"
          ]}>
            {idx + 1}
          </div>
          <%= if @goto_event && not current? && idx < current_idx do %>
            <button
              type="button"
              phx-click={@goto_event}
              phx-value-step={step}
              class={[
                "text-sm underline-offset-2 hover:underline",
                (current? && "font-medium text-stone-900") || "text-stone-700"
              ]}
            >
              {step}
            </button>
          <% else %>
            <div class={["text-sm", (current? && "font-medium text-stone-900") || "text-stone-600"]}>
              {step}
            </div>
          <% end %>
        </div>
        <div :if={idx < length(@steps) - 1} class="h-px w-8 bg-stone-300"></div>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :selected?, :boolean, required: true

  def tab_link(assigns) do
    ~H"""
    <.link
      patch={@path}
      role="tab"
      aria-selected={@selected?}
      class={[
        "inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1",
        "text-sm font-medium ring-offset-white transition-all",
        "focus-visible:ring-ring focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2",
        "disabled:pointer-events-none disabled:opacity-50",
        "border",
        if(@selected?, do: "border-stone-300 bg-stone-50 shadow", else: "border-transparent")
      ]}
    >
      {@label}
    </.link>
    """
  end

  # Navigation Component
  slot :tab, required: true

  def tabs_nav(assigns) do
    ~H"""
    <div
      role="tablist"
      aria-orientation="horizontal"
      class="bg-stone-200/50 inline-flex h-9 rounded-lg p-1"
    >
      {render_slot(@tab)}
    </div>
    """
  end

  # Content Container Component
  slot :inner_block, required: true

  def tabs_content(assigns) do
    ~H"""
    <div class="content border-gray-200/70 relative rounded-md border bg-white p-5">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :links, :list, default: []
  attr :class, :string, default: nil

  def sub_nav(assigns) do
    links =
      assigns.links
      |> List.wrap()
      |> Enum.map(fn link ->
        navigate = Map.get(link, :navigate) || Map.get(link, :path)

        link
        |> Map.put(:navigate, navigate)
        |> Map.put_new(:active, false)
      end)

    assigns = assign(assigns, :links, links)

    ~H"""
    <div :if={Enum.any?(@links)} class={["mb-6", @class]}>
      <.tabs_nav>
        <:tab :for={link <- @links}>
          <.tab_link label={link.label} path={link.navigate} selected?={link.active} />
        </:tab>
      </.tabs_nav>
    </div>
    """
  end

  @doc """
  Renders a navigation breadcrumb trail.

  ## Example

      <.breadcrumb>
        <:crumb label="Home" path="/" />
        <:crumb label="Projects" path="/projects" />
        <:crumb label="Current Project" path="/projects/123" current?={true} />
      </.breadcrumb>

  ## Slots

    * `:crumb` - Required. Multiple crumb items that make up the breadcrumb trail.
      * `:label` - Required. The text to display for this breadcrumb item.
      * `:path` - Required. The navigation path for this breadcrumb item.
      * `:current?` - Optional. Boolean indicating if this is the current page (default: false).

  ## Attributes

    * `:class` - Optional. Additional CSS classes to apply to the nav element.
    * `:separator` - Optional. The separator between breadcrumb items (default: "/").


  """
  # Slot for individual crumb items
  slot :crumb, required: true do
    attr :label, :string, required: true
    attr :path, :string, required: true
    attr :current?, :boolean
  end

  # Main component attributes
  attr :class, :string, default: nil
  attr :separator, :string, default: "/"

  def breadcrumb(assigns) do
    ~H"""
    <nav class={["flex justify-between print:hidden", @class]}>
      <ol class="inline-flex items-center space-x-1 text-base font-semibold">
        <li :for={{crumb, index} <- Enum.with_index(@crumb)} class="flex items-center">
          <.link
            :if={!crumb.current?}
            navigate={crumb.path}
            class="py-1 text-neutral-500 hover:text-neutral-900"
          >
            {crumb.label}
          </.link>

          <span :if={crumb.current?} class="py-1 text-neutral-900">
            {crumb.label}
          </span>

          <span :if={index < length(@crumb) - 1} class="mx-2 text-neutral-400">
            {@separator}
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-stone-800">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a page header with optional heading, subtitle, and actions.
  """
  attr :class, :string, default: nil

  slot :inner_block
  slot :subtitle
  slot :actions

  def header(assigns) do
    has_heading? = not Enum.empty?(assigns.inner_block)
    has_subtitle? = not Enum.empty?(assigns.subtitle)
    has_actions? = not Enum.empty?(assigns.actions)

    assigns =
      assigns
      |> assign(:has_heading?, has_heading?)
      |> assign(:has_subtitle?, has_subtitle?)
      |> assign(:has_actions?, has_actions?)

    ~H"""
    <%= if @has_heading? or @has_subtitle? do %>
      <header class={["mb-4 flex items-center justify-between gap-6", @class]}>
        <div class="min-w-0 flex-1">
          <div :if={@has_heading?} class="min-w-0">
            <h1 class="truncate text-lg font-semibold leading-8 text-stone-800">
              {render_slot(@inner_block)}
            </h1>
          </div>
          <p :if={@has_subtitle?} class="mt-2 text-sm leading-6 text-stone-600">
            {render_slot(@subtitle)}
          </p>
        </div>
        <div :if={@has_actions?} class="flex-none print:hidden">
          {render_slot(@actions)}
        </div>
      </header>
    <% else %>
      <%= if @has_actions? do %>
        <div class={["mb-4 flex items-center justify-end gap-3", @class]}>
          {render_slot(@actions)}
        </div>
      <% end %>
    <% end %>
    """
  end

  @doc """
  Renders a badge with customizable text and conditionally applied color classes based on a keyword list.
  """
  attr :text, :string, required: true, doc: "The text to display inside the badge"

  attr :value, :any,
    required: false,
    default: :default,
    doc: "The value to use for color lookup, can be atom or string"

  attr :colors, :list, default: [], doc: "A keyword list of statuses to CSS classes"
  attr :class, :string, default: nil, doc: "Additional CSS classes"

  def badge(assigns) do
    key =
      if Map.has_key?(assigns, :value) and assigns.value != :default do
        value = assigns.value

        cond do
          is_atom(value) -> value
          is_binary(value) -> String.to_atom(value)
          true -> :default
        end
      else
        cond do
          is_atom(assigns.text) -> assigns.text
          is_binary(assigns.text) -> String.to_atom(assigns.text)
          true -> :default
        end
      end

    color_class = Keyword.get(assigns.colors, key, "bg-stone-100 text-stone-700 border-stone-300")
    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <span class={[
      "inline-flex whitespace-nowrap rounded-full border px-2 text-xs font-normal capitalize leading-5",
      @color_class,
      @class
    ]}>
      {format_label(@text)}
    </span>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-stone-900 hover:text-stone-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  attr :id, :any, default: "timezone"
  attr :name, :any, default: "timezone"

  attr :field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"

  def timezone(assigns) do
    assigns =
      assigns
      |> assign(id: get_in(assigns, [:field, :id]) || assigns.id)
      |> assign(name: get_in(assigns, [:field, :name]) || assigns.name)

    ~H"""
    <input type="hidden" name={@name} id={@id} phx-update="ignore" phx-hook="TimezoneInput" />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-98",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-98"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  attr :href, :string, default: nil
  attr :valid, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def glow_button(assigns) do
    ~H"""
    <a
      :if={@href}
      href={@href}
      ontouchstart=""
      class={["btn-glow h-14 w-full rounded-2xl flex items-center justify-center gap-2.5 no-underline text-[#0C1F15] font-bold text-base", @valid && "btn-glow--on"]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    <button
      :if={!@href}
      ontouchstart=""
      class={["btn-glow h-14 w-full rounded-2xl flex items-center justify-center gap-2.5 border-0 text-[#0C1F15] font-bold text-base cursor-pointer", @valid && "btn-glow--on"]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :href, :string, default: nil
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def leaf_button(assigns) do
    ~H"""
    <a
      :if={@href}
      href={@href}
      ontouchstart=""
      class={["leaf-btn h-14 w-full rounded-2xl flex items-center justify-center gap-2.5 no-underline text-[#0C1F15] font-bold text-base", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    <button
      :if={!@href}
      type={@type}
      ontouchstart=""
      class={["leaf-btn h-14 w-full rounded-2xl flex items-center justify-center gap-2.5 border-0 text-[#0C1F15] font-bold text-base cursor-pointer", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-80"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  # -------------------------------------------------------------------------
  # Member identity components
  # -------------------------------------------------------------------------

  attr :member, :any, required: true
  attr :size, :integer, default: 36
  attr :initials, :string, default: nil

  def member_avatar(assigns) do
    assigns =
      assigns
      |> assign(:auto_initials, member_initials(assigns.member))
      |> assign(:border_radius, round(assigns.size * 0.27))
      |> assign(:font_size, round(assigns.size * 0.39))

    ~H"""
    <div style={"width:#{@size}px;height:#{@size}px;border-radius:#{@border_radius}px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:#{@font_size}px;letter-spacing:-0.01em;color:#fff;#{member_gradient(@member.role)}"}>
      {@initials || @auto_initials}
    </div>
    """
  end

  attr :member, :any, required: true
  attr :rest, :global
  slot :trailing

  def member_card(assigns) do
    ~H"""
    <div style="flex:1;display:flex;align-items:center;gap:10px;min-width:0;" {@rest}>
      <.member_avatar member={@member} />
      <div style="flex:1;min-width:0;">
        <p style="font-size:13px;font-weight:600;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
          {member_display_name(@member)}
        </p>
        <p style="font-size:11px;color:#6E675A;margin-top:1px;">
          {member_subtitle(@member)}
        </p>
      </div>
      <div :if={@trailing != []} style="flex-shrink:0;">
        {render_slot(@trailing)}
      </div>
    </div>
    """
  end

  defp member_initials(%{user: %{first_name: f, last_name: l}}) when is_binary(f) and is_binary(l),
    do: (String.first(f) <> String.first(l)) |> String.upcase()

  defp member_initials(%{user: %{first_name: f}}) when is_binary(f) and f != "",
    do: f |> String.first() |> String.upcase()

  defp member_initials(%{user: %{email: e}}),
    do: e |> to_string() |> String.split("@") |> hd() |> String.first() |> String.upcase()

  defp member_initials(_), do: "?"

  defp member_display_name(%{user: %{first_name: f, last_name: l}})
       when is_binary(f) and is_binary(l),
       do: "#{f} #{l}"

  defp member_display_name(%{user: %{first_name: f}}) when is_binary(f) and f != "", do: f
  defp member_display_name(%{user: %{email: e}}), do: to_string(e)
  defp member_display_name(_), do: "—"

  defp member_subtitle(%{display_title: t}) when is_binary(t) and t != "", do: t
  defp member_subtitle(%{role: :owner}), do: "Owner"
  defp member_subtitle(%{role: :manager}), do: "Manager"
  defp member_subtitle(_), do: "Staff"

  defp member_gradient(role) when role in [:owner, :manager],
    do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"

  defp member_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"
end
