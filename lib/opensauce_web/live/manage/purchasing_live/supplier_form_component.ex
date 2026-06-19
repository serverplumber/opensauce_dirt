defmodule OpenSauceWeb.PurchasingLive.SupplierFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <form
      id="supplier-form"
      phx-target={@myself}
      phx-change="validate"
      phx-submit="save"
      style="display:flex;flex-direction:column;gap:14px;"
    >
      <div>
        <label class="dark-label">Name</label>
        <input
          class="dark-input"
          type="text"
          name="supplier[name]"
          value={@form[:name].value || ""}
          placeholder="Cramer Wholesale"
        />
        <span :for={msg <- @form[:name].errors} class="dark-field-error">{elem(msg, 0)}</span>
      </div>

      <div style="height:1px;background:rgba(52,48,37,0.58);" />

      <div>
        <label class="dark-label">Contact name <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
        <input
          id="supplier-contact-name"
          class="dark-input"
          type="text"
          name="supplier[contact_name]"
          value={@form[:contact_name].value || ""}
          placeholder="Jane Smith"
          phx-hook="TitleCase"
        />
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
        <div>
          <label class="dark-label">Email</label>
          <input
            class="dark-input"
            type="email"
            name="supplier[contact_email]"
            value={@form[:contact_email].value || ""}
            placeholder="jane@nursery.com"
          />
          <span :for={msg <- @form[:contact_email].errors} class="dark-field-error">{elem(msg, 0)}</span>
        </div>
        <div>
          <label class="dark-label">Phone</label>
          <input
            id="supplier-contact-phone"
            class="dark-input"
            type="tel"
            name="supplier[contact_phone]"
            value={@form[:contact_phone].value || ""}
            placeholder="+1 555 000 0000"
            phx-hook="FormatPhone"
          />
        </div>
      </div>

      <div style="height:1px;background:rgba(52,48,37,0.58);" />

      <%!-- addresses --%>
      <div style="display:flex;align-items:center;justify-content:space-between;">
        <p style="font-size:12px;font-weight:700;letter-spacing:0.04em;text-transform:uppercase;color:#6E675A;">
          Addresses
        </p>
        <button
          type="button"
          phx-click="add_address"
          phx-target={@myself}
          ontouchstart=""
          style="display:flex;align-items:center;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
          </svg>
        </button>
      </div>

      <.inputs_for :let={f_addr} field={@form[:addresses]}>
        <div style="background:rgba(52,48,37,0.3);border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:12px;display:flex;flex-direction:column;gap:10px;">
          <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
            <div style="flex:1;">
              <label class="dark-label">Label <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
              <input
                id={f_addr[:name].id}
                class="dark-input"
                type="text"
                name={f_addr[:name].name}
                value={f_addr[:name].value || ""}
                placeholder="Pickup location, Head office…"
                phx-hook="TitleCase"
              />
            </div>
            <button
              type="button"
              phx-click="remove_address"
              phx-value-index={f_addr.index}
              phx-target={@myself}
              ontouchstart=""
              style="flex-shrink:0;margin-top:18px;color:#E87E7E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
              </svg>
            </button>
          </div>

          <div>
            <label class="dark-label">Street</label>
            <input
              class="dark-input"
              type="text"
              name={f_addr[:street].name}
              value={f_addr[:street].value || ""}
              placeholder="123 Nursery Rd"
            />
          </div>

            <div>
              <label class="dark-label">City</label>
              <input
                class="dark-input"
                type="text"
                id={f_addr[:city].id}
                name={f_addr[:city].name}
                value={f_addr[:city].value || ""}
                placeholder="Hadlow"
                phx-hook="TitleCase"
              />
            </div>

          <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;">
            <div>
              <label class="dark-label">Postal code</label>
              <input
                class="dark-input"
                type="text"
                id={f_addr[:zip].id}
                name={f_addr[:zip].name}
                value={f_addr[:zip].value || ""}
                placeholder="A1A 1A1"
                phx-hook="FormatPostal"
              />
            </div>
            <div>
              <label class="dark-label">Province</label>
              <input
                class="dark-input"
                type="text"
                id={f_addr[:province].id}
                name={f_addr[:province].name}
                value={f_addr[:province].value || ""}
                placeholder="Kent"
                phx-hook="TitleCase"
              />
            </div>
            <div>
              <label class="dark-label">Country</label>
              <input
                class="dark-input"
                type="text"
                id={f_addr[:country].id}
                name={f_addr[:country].name}
                value={f_addr[:country].value || ""}
                placeholder="UK"
                phx-hook="TitleCase"
              />
            </div>
          </div>
        </div>
      </.inputs_for>

      <p :if={(@form.source.forms[:addresses] || []) == []} style="font-size:13px;color:#6E675A;text-align:center;padding:8px 0;">
        No addresses yet
      </p>

      <div style="height:1px;background:rgba(52,48,37,0.58);" />

      <div>
        <label class="dark-label">Notes <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
        <textarea
          class="dark-textarea"
          name="supplier[notes]"
          rows="3"
          placeholder="Lead times, minimums, preferred contact times…"
        >{@form[:notes].value}</textarea>
      </div>

      <div style="margin-top:4px;">
        <.glow_button type="submit" valid={form_valid?(@form)}>
          {if @supplier, do: "Save changes", else: "Add supplier"}
        </.glow_button>
      </div>
    </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"supplier" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("add_address", _params, socket) do
    form = Form.add_form(socket.assigns.form, [:addresses])
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("remove_address", %{"index" => index}, socket) do
    form = Form.remove_form(socket.assigns.form, [:addresses, String.to_integer(index)])
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"supplier" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, supplier} ->
        send(self(), {:supplier_saved, supplier})
        {:noreply, push_patch(socket, to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp form_valid?(form) do
    val = form[:name].value
    val != nil and val != ""
  end

  defp assign_form(%{assigns: %{supplier: supplier, current_member: member}} = socket) do
    form =
      if supplier do
        Form.for_update(supplier, :update,
          as: "supplier",
          actor: member,
          tenant: member.organisation_id,
          forms: [
            addresses: [
              data: supplier.addresses,
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update,
              type: :list
            ]
          ]
        )
      else
        Form.for_create(Inventory.Supplier, :create,
          as: "supplier",
          actor: member,
          tenant: member.organisation_id,
          forms: [
            addresses: [
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update,
              type: :list
            ]
          ]
        )
      end

    assign(socket, form: to_form(form))
  end
end
