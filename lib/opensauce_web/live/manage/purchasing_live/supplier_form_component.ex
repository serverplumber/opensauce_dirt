defmodule OpenSauceWeb.PurchasingLive.SupplierFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="supplier-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:contact_name]} type="text" label="Contact Name" />
          <.input field={@form[:contact_phone]} type="text" label="Contact Phone" />
        </div>
        <.input field={@form[:contact_email]} type="email" label="Contact Email" />

        <.inputs_for :let={f_addr} field={@form[:address]}>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <.input field={f_addr[:street]} type="text" label="Street" />
            </div>
            <.input field={f_addr[:city]} type="text" label="City" />
            <.input field={f_addr[:province]} type="text" label="Province" />
            <.input field={f_addr[:zip]} type="text" label="Postal Code" />
            <.input field={f_addr[:country]} type="text" label="Country" />
          </div>
        </.inputs_for>

        <.input field={@form[:notes]} type="textarea" label="Notes" />

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Supplier</.button>
        </:actions>
      </.simple_form>
    </div>
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
  def handle_event("save", %{"supplier" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, supplier} ->
        send(self(), {:supplier_saved, supplier})

        {:noreply, socket |> put_flash(:info, "Supplier saved") |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{supplier: supplier}} = socket) do
    member = socket.assigns.current_member

    form =
      if supplier do
        Form.for_update(supplier, :update,
          as: "supplier",
          actor: member,
          tenant: member.organisation_id,
          forms: [
            address: [
              data: supplier.address,
              resource: OpenSauce.CRM.Address,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        Form.for_create(Inventory.Supplier, :create,
          as: "supplier",
          actor: member,
          tenant: member.organisation_id,
          forms: [
            address: [
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
