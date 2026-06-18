defmodule OpenSauceWeb.CustomerLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="customer-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:16px;"
      >
        <div style="display:flex;gap:8px;">
          <label style={"flex:1;display:flex;align-items:center;justify-content:center;padding:10px;border-radius:12px;cursor:pointer;font-size:14px;font-weight:600;#{if company_type?(@form), do: "background:rgba(84,181,126,0.12);border:1.5px solid rgba(84,181,126,0.4);color:#54B57E;", else: "background:#54B57E;border:1.5px solid #54B57E;color:#0C1F15;"}"}>
            <input
              type="radio"
              name={@form[:type].name}
              value="individual"
              checked={!company_type?(@form)}
              style="display:none;"
            />
            Individual
          </label>
          <label style={"flex:1;display:flex;align-items:center;justify-content:center;padding:10px;border-radius:12px;cursor:pointer;font-size:14px;font-weight:600;#{if company_type?(@form), do: "background:#54B57E;border:1.5px solid #54B57E;color:#0C1F15;", else: "background:rgba(84,181,126,0.12);border:1.5px solid rgba(84,181,126,0.4);color:#54B57E;"}"}>
            <input
              type="radio"
              name={@form[:type].name}
              value="company"
              checked={company_type?(@form)}
              style="display:none;"
            />
            Company
          </label>
        </div>

        <div style="display:flex;flex-direction:column;gap:12px;">
          <div>
            <p class="dark-label">{if company_type?(@form), do: "Company name", else: "Nickname"}</p>
            <input
              type="text"
              id={@form[:company_name_nickname].id}
              name={@form[:company_name_nickname].name}
              value={@form[:company_name_nickname].value}
              class="dark-input"
              style="width:100%;"
            />
          </div>
          <div style="display:flex;gap:10px;">
            <div style="flex:1;">
              <p class="dark-label">First name</p>
              <input
                type="text"
                id={@form[:first_name].id}
                name={@form[:first_name].name}
                value={@form[:first_name].value}
                class="dark-input"
                style="width:100%;"
              />
            </div>
            <div style="flex:1;">
              <p class="dark-label">Last name</p>
              <input
                type="text"
                id={@form[:last_name].id}
                name={@form[:last_name].name}
                value={@form[:last_name].value}
                class="dark-input"
                style="width:100%;"
              />
            </div>
          </div>
          <div>
            <p class="dark-label">Email</p>
            <input
              type="email"
              id={@form[:email].id}
              name={@form[:email].name}
              value={@form[:email].value}
              class="dark-input"
              style="width:100%;"
            />
          </div>
          <div>
            <p class="dark-label">Phone</p>
            <input
              type="tel"
              id={@form[:phone].id}
              name={@form[:phone].name}
              value={@form[:phone].value}
              class="dark-input"
              style="width:100%;"
            />
          </div>
        </div>

        <div style="display:flex;flex-direction:column;gap:12px;">
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Garden Addresses
            </p>
            <button
              type="button"
              phx-click="add_garden_address"
              phx-target={@myself}
              ontouchstart=""
              style="background:none;border:1.5px solid rgba(52,48,37,0.58);border-radius:10px;padding:6px 14px;font-size:12px;font-weight:600;color:#9A9384;cursor:pointer;"
            >
              + Add address
            </button>
          </div>

          <.inputs_for :let={f_garden} field={@form[:garden_addresses]}>
            <div style="position:relative;background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:16px;">
              <input type="hidden" name={f_garden[:is_garden].name} value="true" />
              <input type="hidden" name={f_garden[:is_billing].name} value="false" />
              <input type="hidden" name={f_garden[:is_indoor].name} value="false" />
              <button
                type="button"
                phx-click="remove_garden_address"
                phx-value-path={f_garden.name}
                phx-target={@myself}
                ontouchstart=""
                style="position:absolute;top:12px;right:12px;background:none;border:none;color:#E87E7E;font-size:16px;line-height:1;cursor:pointer;padding:4px;"
              >
                ×
              </button>
              <div style="display:flex;flex-direction:column;gap:10px;">
                <div>
                  <p class="dark-label">Name</p>
                  <input
                    type="text"
                    id={f_garden[:name].id}
                    name={f_garden[:name].name}
                    value={f_garden[:name].value}
                    placeholder="e.g. North Field"
                    class="dark-input"
                    style="width:100%;"
                  />
                </div>
                <div>
                  <p class="dark-label">Street</p>
                  <input
                    type="text"
                    id={f_garden[:street].id}
                    name={f_garden[:street].name}
                    value={f_garden[:street].value}
                    class="dark-input"
                    style="width:100%;"
                  />
                </div>
                <div style="display:flex;gap:10px;">
                  <div style="flex:1;">
                    <p class="dark-label">City</p>
                    <input
                      type="text"
                      id={f_garden[:city].id}
                      name={f_garden[:city].name}
                      value={f_garden[:city].value}
                      class="dark-input"
                      style="width:100%;"
                    />
                  </div>
                  <div style="flex:1;">
                    <p class="dark-label">Province</p>
                    <input
                      type="text"
                      id={f_garden[:province].id}
                      name={f_garden[:province].name}
                      value={f_garden[:province].value}
                      class="dark-input"
                      style="width:100%;"
                    />
                  </div>
                </div>
                <div>
                  <p class="dark-label">Postal Code</p>
                  <input
                    type="text"
                    id={f_garden[:zip].id}
                    name={f_garden[:zip].name}
                    value={f_garden[:zip].value}
                    class="dark-input"
                    style="width:100%;"
                  />
                </div>
              </div>
            </div>
          </.inputs_for>
        </div>

        <button
          type="submit"
          phx-disable-with="Saving…"
          ontouchstart=""
          style="width:100%;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
        >
          Save Customer
        </button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, customer_params))}
  end

  def handle_event("add_garden_address", _params, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, [:garden_addresses])
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("remove_garden_address", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: customer_params) do
      {:ok, customer} ->
        notify_parent({:saved, customer})

        {:noreply,
         socket
         |> put_flash(:info, "Customer #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp company_type?(form) do
    case Phoenix.HTML.Form.input_value(form, :type) do
      :company -> true
      "company" -> true
      _ -> false
    end
  end

  defp assign_form(%{assigns: %{customer: customer}} = socket) do
    member = socket.assigns.current_member

    form =
      if customer do
        AshPhoenix.Form.for_update(customer, :update,
          as: "customer",
          actor: member,
          tenant: member.organisation_id,
          forms: [
            garden_addresses: [
              type: :list,
              data: customer.garden_addresses || [],
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        AshPhoenix.Form.for_create(OpenSauce.CRM.Customer, :create,
          as: "customer",
          actor: member,
          tenant: member.organisation_id,
          forms: [
            garden_addresses: [
              type: :list,
              data: [],
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      end

    assign(socket, form: to_form(form))
  end
end
