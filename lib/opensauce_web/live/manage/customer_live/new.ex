defmodule OpenSauceWeb.CustomerLive.New do
  @moduledoc false
  use OpenSauceWeb, :live_view

  @empty_draft %{
    "name" => "",
    "street" => "",
    "city" => "",
    "province" => "",
    "zip" => "",
    "notes" => "",
    "is_billing" => "false"
  }

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member

    form =
      AshPhoenix.Form.for_create(OpenSauce.CRM.Customer, :create,
        as: "customer",
        actor: member,
        tenant: member.organisation_id
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "New Customer")
     |> assign(:form, form)
     |> assign(:gardens, [])
     |> assign(:billing_index, nil)
     |> assign(:draft, @empty_draft)
     |> assign(:show_garden_sheet, false)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto space-y-4 pb-8">
      <div class="flex items-center gap-3 pt-1">
        <.link navigate={~p"/manage/customers"} class="text-stone-500 hover:text-stone-700 p-1 -ml-1">
          <.icon name="hero-arrow-left" class="h-5 w-5" />
        </.link>
        <h1 class="text-lg font-semibold text-stone-900">New Customer</h1>
      </div>

      <.form for={@form} id="customer-form" phx-submit="save" phx-change="validate">
        <%!-- Contact section --%>
        <div class="space-y-4 bg-white rounded-xl border border-stone-200 p-4 mb-4">
          <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wider">Contact</h2>

          <.input
            field={@form[:type]}
            type="radiogroup"
            options={[{"Individual", :individual}, {"Company", :company}]}
            value={@form[:type].value || :individual}
          />

          <.input
            field={@form[:company_name_nickname]}
            type="text"
            label={if company_type?(@form), do: "Company name", else: "Nickname"}
          />

          <div class="grid grid-cols-2 gap-3">
            <.input field={@form[:first_name]} type="text" label="First name" />
            <.input field={@form[:last_name]} type="text" label="Last name" />
          </div>

          <.input field={@form[:email]} type="email" label="Email" />
          <.input field={@form[:phone]} type="tel" label="Phone" />
        </div>

        <%!-- Gardens section --%>
        <div class="space-y-3 bg-white rounded-xl border border-stone-200 p-4 mb-4">
          <div class="flex items-center justify-between">
            <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wider">Gardens</h2>
            <button
              type="button"
              phx-click="open_garden_sheet"
              class="text-sm font-medium text-amber-600 hover:text-amber-700 active:text-amber-800"
            >
              + Add garden
            </button>
          </div>

          <div :if={Enum.empty?(@gardens)} class="text-sm text-stone-400 text-center py-3">
            Add at least one garden
          </div>

          <div :for={{garden, i} <- Enum.with_index(@gardens)} id={"garden-#{i}"} class="rounded-lg border border-stone-200 p-3">
            <div class="flex items-start gap-2">
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-stone-900 truncate">
                  {if garden["name"] != "", do: garden["name"], else: "Unnamed garden"}
                </p>
                <p :if={short_address(garden) != ""} class="text-xs text-stone-500 mt-0.5 truncate">
                  {short_address(garden)}
                </p>
              </div>
              <button
                type="button"
                phx-click="remove_garden"
                phx-value-index={i}
                class="text-stone-300 hover:text-red-400 shrink-0 p-0.5"
                aria-label="Remove garden"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>

            <button
              :if={length(@gardens) > 1}
              type="button"
              phx-click="set_billing"
              phx-value-index={i}
              class={"mt-2 flex items-center gap-1.5 text-xs " <> if(@billing_index == i, do: "text-amber-600 font-medium", else: "text-stone-400 hover:text-stone-600")}
            >
              <.icon
                name={if @billing_index == i, do: "hero-star-solid", else: "hero-star"}
                class="h-3.5 w-3.5"
              />
              {if @billing_index == i, do: "Billing address", else: "Use as billing"}
            </button>

            <span
              :if={length(@gardens) == 1}
              class="mt-2 flex items-center gap-1.5 text-xs text-amber-600 font-medium"
            >
              <.icon name="hero-star-solid" class="h-3.5 w-3.5" />
              Billing address
            </span>
          </div>
        </div>

        <.button type="submit" variant={:primary} class="w-full" phx-disable-with="Saving…">
          Create customer
        </.button>
      </.form>
    </div>

    <%!-- H2 · Add garden slide-up sheet --%>
    <div
      :if={@show_garden_sheet}
      id="garden-sheet"
      class="fixed inset-0 z-50"
      role="dialog"
      aria-modal="true"
      aria-label="Add garden"
    >
      <div class="absolute inset-0 bg-black/40" phx-click="close_garden_sheet"></div>
      <div class="absolute bottom-0 left-0 right-0 bg-white rounded-t-2xl shadow-2xl max-h-[85dvh] flex flex-col">
        <div class="flex items-center justify-between px-4 py-3 border-b border-stone-100 shrink-0">
          <h3 class="text-base font-semibold text-stone-900">Add garden</h3>
          <button
            type="button"
            phx-click="close_garden_sheet"
            class="text-stone-400 hover:text-stone-600 p-1 -mr-1"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <.form
          for={:garden}
          id="garden-draft-form"
          phx-submit="add_garden"
          class="flex-1 overflow-y-auto p-4 space-y-4"
        >
          <.input
            name="garden[name]"
            id="draft-name"
            value={@draft["name"]}
            label="Garden name"
            placeholder="e.g. North Field"
          />
          <.input name="garden[street]" id="draft-street" value={@draft["street"]} label="Street" />
          <div class="grid grid-cols-2 gap-3">
            <.input name="garden[city]" id="draft-city" value={@draft["city"]} label="City" />
            <.input
              name="garden[province]"
              id="draft-province"
              value={@draft["province"]}
              label="Province"
            />
          </div>
          <.input name="garden[zip]" id="draft-zip" value={@draft["zip"]} label="Postal code" />
          <.input
            name="garden[notes]"
            id="draft-notes"
            value={@draft["notes"]}
            label="Notes"
            placeholder="Gate code, access info…"
          />

          <label class="flex items-center justify-between rounded-xl border border-stone-200 px-4 py-3 cursor-pointer">
            <div>
              <p class="text-sm font-medium text-stone-900">Billing address</p>
              <p class="text-xs text-stone-500 mt-0.5">Use this garden for invoices</p>
            </div>
            <button
              type="button"
              phx-click="toggle_draft_billing"
              class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors " <> if(@draft["is_billing"] == "true", do: "bg-amber-500", else: "bg-stone-200")}
              role="switch"
              aria-checked={@draft["is_billing"] == "true"}
            >
              <span class={"inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform " <> if(@draft["is_billing"] == "true", do: "translate-x-6", else: "translate-x-1")} />
            </button>
            <input type="hidden" name="garden[is_billing]" value={@draft["is_billing"]} />
          </label>

          <div class="flex gap-3 pt-2 pb-safe">
            <button
              type="button"
              phx-click="close_garden_sheet"
              class="flex-1 rounded-xl border border-stone-200 py-3 text-sm font-medium text-stone-700 hover:bg-stone-50 active:bg-stone-100"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="flex-1 rounded-xl bg-amber-500 py-3 text-sm font-medium text-white hover:bg-amber-600 active:bg-amber-700"
            >
              Add garden
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"customer" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form.source, params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("open_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: true, draft: @empty_draft)}
  end

  def handle_event("close_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: false)}
  end

  def handle_event("add_garden", %{"garden" => params}, socket) do
    is_billing = params["is_billing"] == "true"
    garden = Map.put(params, "is_garden", "true")
    new_index = length(socket.assigns.gardens)

    billing_index =
      cond do
        is_billing -> new_index
        is_nil(socket.assigns.billing_index) -> 0
        true -> socket.assigns.billing_index
      end

    {:noreply,
     socket
     |> assign(:gardens, socket.assigns.gardens ++ [garden])
     |> assign(:billing_index, billing_index)
     |> assign(:show_garden_sheet, false)
     |> assign(:draft, @empty_draft)}
  end

  def handle_event("remove_garden", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    gardens = List.delete_at(socket.assigns.gardens, idx)

    billing_index =
      cond do
        Enum.empty?(gardens) -> nil
        socket.assigns.billing_index == idx -> 0
        socket.assigns.billing_index > idx -> socket.assigns.billing_index - 1
        true -> socket.assigns.billing_index
      end

    {:noreply, assign(socket, gardens: gardens, billing_index: billing_index)}
  end

  def handle_event("set_billing", %{"index" => idx_str}, socket) do
    {:noreply, assign(socket, billing_index: String.to_integer(idx_str))}
  end

  def handle_event("toggle_draft_billing", _params, socket) do
    new_val = if socket.assigns.draft["is_billing"] == "true", do: "false", else: "true"
    {:noreply, assign(socket, draft: Map.put(socket.assigns.draft, "is_billing", new_val))}
  end

  def handle_event("save", %{"customer" => params}, socket) do
    gardens_with_billing =
      socket.assigns.gardens
      |> Enum.with_index()
      |> Enum.map(fn {g, i} ->
        Map.put(g, "is_billing", to_string(i == socket.assigns.billing_index))
      end)

    full_params = Map.put(params, "garden_addresses", gardens_with_billing)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: full_params) do
      {:ok, customer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer created")
         |> push_navigate(to: ~p"/manage/customers/#{customer.reference}")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  defp company_type?(form) do
    case Phoenix.HTML.Form.input_value(form, :type) do
      :company -> true
      "company" -> true
      _ -> false
    end
  end

  defp short_address(g) do
    [g["street"], g["city"], g["zip"]]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end
end
