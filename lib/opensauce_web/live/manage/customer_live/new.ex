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
    "is_billing" => "false",
    "is_garden" => "true"
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
     |> assign(:show_garden_sheet, false)
     |> assign(:customer_type, :individual)
     |> assign(:garden_error, nil)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :main_bg, "bg-[#16140E]")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- header --%>
      <div style="padding:12px 16px 14px;display:flex;align-items:center;gap:12px;">
        <.link navigate={~p"/manage/customers"}>
          <button type="button" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;" ontouchstart="">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        </.link>
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;margin:0;">
          New Customer
        </h1>
      </div>

      <.form for={@form} id="customer-form" phx-submit="save" phx-change="validate">
        <div style="padding:0 16px 140px;display:flex;flex-direction:column;gap:20px;">

          <%!-- type toggle --%>
          <div>
            <span class="dark-label">Type</span>
            <div style="display:flex;gap:8px;">
              <button
                :for={{type_val, label} <- [{:individual, "Individual"}, {:company, "Company"}]}
                type="button"
                phx-click="set_type"
                phx-value-type={type_val}
                ontouchstart=""
                style={"flex:1;border-radius:12px;border:1.5px solid;padding:12px;font-size:13.5px;font-weight:700;cursor:pointer;transition:background .12s ease,color .12s ease,border-color .12s ease;#{if @customer_type == type_val, do: "background:#54B57E;color:#0C1F15;border-color:#54B57E;", else: "background:#211E16;color:#9A9384;border-color:rgba(52,48,37,0.58);"}"}
              >
                {label}
              </button>
            </div>
            <input type="hidden" name="customer[type]" value={@customer_type} />
          </div>

          <%!-- company name / nickname --%>
          <div>
            <label class="dark-label" for={@form[:company_name_nickname].id}>
              {if @customer_type == :company, do: "Company name", else: "Nickname"}
            </label>
            <input
              class="dark-input"
              type="text"
              name={@form[:company_name_nickname].name}
              id={@form[:company_name_nickname].id}
              value={@form[:company_name_nickname].value || ""}
              phx-debounce="300"
            />
            <span :for={msg <- @form[:company_name_nickname].errors} class="dark-field-error">{elem(msg, 0)}</span>
          </div>

          <%!-- first / last name --%>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div>
              <label class="dark-label" for={@form[:first_name].id}>First name</label>
              <input
                class="dark-input"
                type="text"
                name={@form[:first_name].name}
                id={@form[:first_name].id}
                value={@form[:first_name].value || ""}
                phx-debounce="300"
              />
              <span :for={msg <- @form[:first_name].errors} class="dark-field-error">{elem(msg, 0)}</span>
            </div>
            <div>
              <label class="dark-label" for={@form[:last_name].id}>Last name</label>
              <input
                class="dark-input"
                type="text"
                name={@form[:last_name].name}
                id={@form[:last_name].id}
                value={@form[:last_name].value || ""}
                phx-debounce="300"
              />
              <span :for={msg <- @form[:last_name].errors} class="dark-field-error">{elem(msg, 0)}</span>
            </div>
          </div>

          <%!-- email --%>
          <div>
            <label class="dark-label" for={@form[:email].id}>Email</label>
            <input
              class="dark-input"
              type="email"
              name={@form[:email].name}
              id={@form[:email].id}
              value={@form[:email].value || ""}
              phx-debounce="300"
            />
            <span :for={msg <- @form[:email].errors} class="dark-field-error">{elem(msg, 0)}</span>
          </div>

          <%!-- phone --%>
          <div>
            <label class="dark-label" for={@form[:phone].id}>Phone</label>
            <input
              class="dark-input"
              type="tel"
              name={@form[:phone].name}
              id={@form[:phone].id}
              value={@form[:phone].value || ""}
              phx-hook="FormatPhone"
              phx-debounce="300"
            />
            <span :for={msg <- @form[:phone].errors} class="dark-field-error">{elem(msg, 0)}</span>
          </div>

          <%!-- gardens --%>
          <div>
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
              <span class="dark-label" style="margin-bottom:0;">Gardens</span>
              <button type="button" phx-click="open_garden_sheet"
                style="display:flex;align-items:center;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                  <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
                </svg>
              </button>
            </div>

            <button :if={Enum.empty?(@gardens)} type="button" phx-click="open_garden_sheet" ontouchstart=""
              style={"width:100%;border-radius:12px;border:1.5px dashed;padding:14px;text-align:center;background:transparent;cursor:pointer;#{if @garden_error, do: "border-color:#E87E7E;", else: "border-color:rgba(52,48,37,0.58);"}"}>
              <p style={"font-size:13px;#{if @garden_error, do: "color:#E87E7E;", else: "color:#6E675A;"}"}>{@garden_error || "Add at least one garden"}</p>
            </button>

            <div :if={not Enum.empty?(@gardens)} style="display:flex;flex-direction:column;gap:8px;">
              <div :for={{garden, i} <- Enum.with_index(@gardens)} id={"garden-#{i}"} class="jcard">
                <div style="display:flex;align-items:flex-start;gap:10px;">
                  <div style="flex:1;min-width:0;">
                    <p style="font-size:14px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                      {if garden["name"] != "", do: garden["name"], else: "Unnamed garden"}
                    </p>
                    <p :if={short_address(garden) != ""} style="font-size:12px;color:#9A9384;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                      {short_address(garden)}
                    </p>
                    <p style="font-size:11.5px;color:#6E675A;margin-top:3px;">
                      {if garden["is_garden"] == "true", do: "Outdoor", else: "Indoor"}
                    </p>
                  </div>
                  <button type="button" phx-click="remove_garden" phx-value-index={i}
                    style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;flex:0 0 auto;">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none">
                      <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                    </svg>
                  </button>
                </div>
                <div style="margin-top:8px;">
                  <span :if={length(@gardens) == 1 or @billing_index == i}
                    style="display:inline-flex;align-items:center;gap:5px;font-size:11.5px;font-weight:700;color:#54B57E;">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                    </svg>
                    Billing address
                  </span>
                  <button :if={length(@gardens) > 1 and @billing_index != i}
                    type="button" phx-click="set_billing" phx-value-index={i} ontouchstart=""
                    style="display:inline-flex;align-items:center;gap:5px;font-size:11.5px;font-weight:600;color:#6E675A;background:none;border:none;padding:0;cursor:pointer;">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                    </svg>
                    Use as billing
                  </button>
                </div>
              </div>
            </div>
          </div>

        </div>

        <%!-- sticky CTA --%>
        <div style="position:fixed;bottom:74px;left:0;right:0;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);padding:12px 16px;">
          <.glow_button valid={customer_can_submit?(@form, @customer_type)} type="submit" phx-disable-with="Saving…">
            Create customer
          </.glow_button>
        </div>

      </.form>

      <%!-- add garden sheet --%>
      <div :if={@show_garden_sheet}
        id="garden-sheet"
        style="position:fixed;inset:0;z-index:50;"
        role="dialog" aria-modal="true" aria-label="Add garden">
        <div style="position:absolute;inset:0;background:rgba(0,0,0,0.6);" phx-click="close_garden_sheet"></div>
        <div style="position:absolute;bottom:0;left:0;right:0;background:#211E16;border-radius:20px 20px 0 0;max-height:90dvh;display:flex;flex-direction:column;">

          <div style="display:flex;align-items:center;justify-content:space-between;padding:16px 16px 12px;border-bottom:1px solid rgba(52,48,37,0.58);flex:0 0 auto;">
            <h3 style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;margin:0;">Add garden</h3>
            <button type="button" phx-click="close_garden_sheet" ontouchstart=""
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
              </svg>
            </button>
          </div>

          <.form for={:garden} id="garden-draft-form" phx-submit="add_garden" phx-change="update_draft"
            style="flex:1;overflow-y:auto;padding:16px 16px calc(74px + 16px);display:flex;flex-direction:column;gap:16px;">

            <div>
              <label class="dark-label" for="draft-name">Garden name</label>
              <input class="dark-input" type="text" name="garden[name]" id="draft-name" value={@draft["name"]} placeholder="e.g. North Field" />
              <div style="display:flex;gap:8px;margin-top:10px;">
                <button
                  :for={{flag, label} <- [{"true", "Outdoor"}, {"false", "Indoor"}]}
                  type="button"
                  phx-click="toggle_draft_location"
                  phx-value-outdoor={flag}
                  ontouchstart=""
                  style={"flex:1;border-radius:10px;border:1.5px solid;padding:9px;font-size:13px;font-weight:700;cursor:pointer;transition:background .12s ease,color .12s ease,border-color .12s ease;#{if @draft["is_garden"] == flag, do: "background:#54B57E;color:#0C1F15;border-color:#54B57E;", else: "background:#16140E;color:#9A9384;border-color:rgba(52,48,37,0.58);"}"}
                >
                  {label}
                </button>
              </div>
              <input type="hidden" name="garden[is_garden]" value={@draft["is_garden"]} />
            </div>
            <div>
              <label class="dark-label" for="draft-street">Street</label>
              <input class="dark-input" type="text" name="garden[street]" id="draft-street" value={@draft["street"]} />
            </div>
              <div>
                <label class="dark-label" for="draft-city">City</label>
                <input class="dark-input" type="text" name="garden[city]" id="draft-city" value={@draft["city"]} phx-hook="TitleCase" />
              </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div>
                <label class="dark-label" for="draft-zip">Postal code</label>
                <input class="dark-input" type="text" name="garden[zip]" id="draft-zip" value={@draft["zip"]} phx-hook="FormatPostal" />
              </div>
              <div>
                <label class="dark-label" for="draft-province">Province</label>
                <input class="dark-input" type="text" name="garden[province]" id="draft-province" value={@draft["province"]} phx-hook="TitleCase" />
              </div>
            </div>
            <div>
              <label class="dark-label" for="draft-notes">Notes</label>
              <textarea class="dark-textarea" name="garden[notes]" id="draft-notes" rows="2" placeholder="Gate code, access info…"><%= @draft["notes"] %></textarea>
            </div>

            <%!-- billing toggle --%>
            <div style="display:flex;align-items:center;justify-content:space-between;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);padding:12px 14px;">
              <p style="font-size:14px;font-weight:600;color:#F4EFE2;">Billing address</p>
              <button type="button" phx-click="toggle_draft_billing" ontouchstart=""
                style={"position:relative;display:inline-flex;height:24px;width:44px;align-items:center;border-radius:999px;border:none;cursor:pointer;transition:background .12s ease;#{if @draft["is_billing"] == "true", do: "background:#54B57E;", else: "background:rgba(52,48,37,0.8);"}"}
                role="switch" aria-checked={@draft["is_billing"] == "true"}>
                <span style={"position:absolute;height:18px;width:18px;border-radius:50%;background:#F4EFE2;transition:transform .12s ease;#{if @draft["is_billing"] == "true", do: "transform:translateX(22px);", else: "transform:translateX(3px);"}"}></span>
              </button>
              <input type="hidden" name="garden[is_billing]" value={@draft["is_billing"]} />
            </div>

            <div style="display:flex;gap:10px;padding-bottom:8px;">
              <button type="button" phx-click="close_garden_sheet" ontouchstart=""
                style="flex:1;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:transparent;padding:13px;font-size:13.5px;font-weight:700;color:#9A9384;cursor:pointer;">
                Cancel
              </button>
              <button type="submit" ontouchstart=""
                style="flex:1;border-radius:12px;border:none;background:#54B57E;padding:13px;font-size:13.5px;font-weight:700;color:#0C1F15;cursor:pointer;">
                Add garden
              </button>
            </div>

          </.form>
        </div>
      </div>

    </div>
    """
  end

  @impl true
  def handle_event("set_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :customer_type, String.to_existing_atom(type))}
  end

  def handle_event("validate", %{"customer" => params}, socket) do
    params = Map.put_new(params, "type", to_string(socket.assigns.customer_type))
    ash_form = socket.assigns.form.source
    form = AshPhoenix.Form.validate(ash_form, params, errors: ash_form.submitted_once?)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("open_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: true, draft: @empty_draft)}
  end

  def handle_event("close_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: false)}
  end

  def handle_event("toggle_draft_location", %{"outdoor" => flag}, socket) do
    {:noreply, assign(socket, draft: Map.put(socket.assigns.draft, "is_garden", flag))}
  end

  def handle_event("add_garden", %{"garden" => params}, socket) do
    is_billing = params["is_billing"] == "true"
    is_outdoor = Map.get(params, "is_garden", "true") == "true"

    garden =
      params
      |> Map.put("is_garden", to_string(is_outdoor))
      |> Map.put("is_indoor", to_string(!is_outdoor))

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
     |> assign(:draft, @empty_draft)
     |> assign(:garden_error, nil)}
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

  def handle_event("update_draft", %{"garden" => params}, socket) do
    {:noreply, assign(socket, :draft, Map.merge(socket.assigns.draft, params))}
  end

  def handle_event("toggle_draft_billing", _params, socket) do
    new_val = if socket.assigns.draft["is_billing"] == "true", do: "false", else: "true"
    {:noreply, assign(socket, draft: Map.put(socket.assigns.draft, "is_billing", new_val))}
  end

  def handle_event("save", _params, socket) when socket.assigns.gardens == [] do
    {:noreply, assign(socket, :garden_error, "At least one garden is required")}
  end

  def handle_event("save", %{"customer" => params}, socket) do
    member = socket.assigns.current_member
    params = Map.put_new(params, "type", to_string(socket.assigns.customer_type))

    gardens_with_billing =
      socket.assigns.gardens
      |> Enum.with_index()
      |> Enum.map(fn {g, i} ->
        g
        |> Map.put("is_billing", to_string(i == socket.assigns.billing_index))
        |> nilify_map_values()
      end)

    full_params = Map.put(params, "garden_addresses", gardens_with_billing)

    case OpenSauce.CRM.Customer
         |> Ash.Changeset.for_create(:create, full_params,
           actor: member,
           tenant: member.organisation_id
         )
         |> Ash.create() do
      {:ok, customer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer created")
         |> push_navigate(to: ~p"/manage/customers/#{customer.reference}")}

      {:error, %Ash.Changeset{} = changeset} ->
        form =
          AshPhoenix.Form.for_create(OpenSauce.CRM.Customer, :create,
            as: "customer",
            actor: member,
            tenant: member.organisation_id
          )
          |> AshPhoenix.Form.validate(params, errors: true)

        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, ash_error_summary(changeset))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save customer.")}
    end
  end

  defp customer_can_submit?(form, :company) do
    val = form[:company_name_nickname].value
    val != nil and val != ""
  end

  defp customer_can_submit?(form, _individual) do
    val = form[:first_name].value
    val != nil and val != ""
  end

  defp short_address(g) do
    [g["street"], g["city"], g["zip"]]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp ash_error_summary(%Ash.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn
      %{field: field, message: msg} when not is_nil(field) -> "#{field}: #{msg}"
      %{message: msg} -> msg
      e -> inspect(e)
    end)
    |> Enum.join(", ")
  end

  defp ash_error_summary(_), do: "Could not save customer."

  defp nilify(""), do: nil
  defp nilify(s), do: s
  defp nilify_map_values(map), do: Map.new(map, fn {k, v} -> {k, nilify(v)} end)
end
