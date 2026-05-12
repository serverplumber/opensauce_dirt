defmodule OpenSauceWeb.CustomerLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="customer-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-8 bg-white">
          <.input
            field={@form[:type]}
            type="radiogroup"
            options={[{"Individual", :individual}, {"Company", :company}]}
            value={@form[:type].value || :individual}
          />

          <div class="space-y-4">
            <.input
              field={@form[:company_name_nickname]}
              type="text"
              label={if company_type?(@form), do: "Company name", else: "Nickname"}
              required={company_type?(@form)}
            />
            <div class="flex flex-row space-x-4">
              <.input field={@form[:first_name]} type="text" label="First name" />
              <.input field={@form[:last_name]} type="text" label="Last name" />
            </div>
            <.input field={@form[:email]} type="email" label="Email" />
            <.input field={@form[:phone]} type="tel" label="Phone" />
          </div>

          <div class="space-y-4">
            <div class="flex items-center gap-3">
              <label class="text-sm font-semibold leading-6 text-zinc-800">Billing Address</label>
              <label class="flex cursor-pointer items-center gap-1.5 text-sm font-normal text-stone-500">
                <input
                  type="checkbox"
                  checked={@same_as_billing}
                  phx-click="toggle_same_as_billing"
                  phx-target={@myself}
                  class="rounded border-stone-300 text-primary-600"
                />
                Same as first garden address
              </label>
            </div>
            <.inputs_for :if={not @same_as_billing} :let={f_addr} field={@form[:billing_address]}>
              <input type="hidden" name={f_addr[:is_billing].name} value="true" />
              <input type="hidden" name={f_addr[:is_garden].name} value="false" />
              <input type="hidden" name={f_addr[:is_indoor].name} value="false" />
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <.input field={f_addr[:street]} type="text" label="Street" />
                </div>
                <.input field={f_addr[:city]} type="text" label="City" />
                <.input field={f_addr[:province]} type="text" label="Province" />
                <.input field={f_addr[:zip]} type="text" label="Postal Code" />
              </div>
            </.inputs_for>
          </div>

          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <label class="text-sm font-semibold leading-6 text-zinc-800">Garden Addresses</label>
              <.button
                type="button"
                variant={:outline}
                phx-click="add_garden_address"
                phx-target={@myself}
              >
                + Add address
              </.button>
            </div>

            <.inputs_for :let={f_garden} field={@form[:garden_addresses]}>
              <div class="relative rounded-lg border border-stone-200 bg-stone-50 p-4">
                <input type="hidden" name={f_garden[:is_garden].name} value="true" />
                <input type="hidden" name={f_garden[:is_billing].name} value="false" />
                <input type="hidden" name={f_garden[:is_indoor].name} value="false" />
                <button
                  type="button"
                  phx-click="remove_garden_address"
                  phx-value-path={f_garden.name}
                  phx-target={@myself}
                  class="absolute top-3 right-3 text-stone-400 hover:text-red-500"
                >
                  <.icon name="hero-x-mark" class="h-4 w-4" />
                </button>
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div class="sm:col-span-2">
                    <.input field={f_garden[:name]} type="text" label="Name" placeholder="e.g. North Field" />
                  </div>
                  <div class="sm:col-span-2">
                    <.input field={f_garden[:street]} type="text" label="Street" />
                  </div>
                  <.input field={f_garden[:city]} type="text" label="City" />
                  <.input field={f_garden[:province]} type="text" label="Province" />
                  <.input field={f_garden[:zip]} type="text" label="Postal Code" />
                </div>
              </div>
            </.inputs_for>
          </div>
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Customer</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    same_as_billing = Enum.empty?(assigns.customer && assigns.customer.garden_addresses || [])
    {:ok, socket |> assign(assigns) |> assign(:same_as_billing, same_as_billing) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, customer_params))}
  end

  def handle_event("toggle_same_as_billing", _params, socket) do
    {:noreply, assign(socket, :same_as_billing, not socket.assigns.same_as_billing)}
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
            billing_address: [
              data: customer.billing_address,
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update
            ],
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
            billing_address: [
              data: nil,
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update
            ],
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
