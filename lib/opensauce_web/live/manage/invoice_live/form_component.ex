defmodule OpenSauceWeb.InvoiceLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.CRM

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} id="invoice-form" phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="space-y-4">
          <.input field={@form[:reference]} type="text" label="Reference" placeholder="INV-001" />
          <.input field={@form[:customer_id]} type="select" label="Customer"
            options={customer_options(@current_member)} prompt="Select customer" />
          <.input field={@form[:engagement_id]} type="select" label="Engagement (optional)"
            options={engagement_options(@current_member)} prompt="None" />
          <.input field={@form[:amount]} type="number" label="Amount" step="0.01" min="0" />
          <.input field={@form[:issued_on]} type="date" label="Issued On" />
          <.input field={@form[:due_on]} type="date" label="Due On (optional)" />
          <.input field={@form[:status]} type="select" label="Status"
            options={[{"Draft", :draft}, {"Sent", :sent}, {"Paid", :paid}, {"Void", :void}]} />
          <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
        </div>
        <div class="mt-6 flex justify-end gap-2">
          <.button type="submit" variant={:primary} phx-disable-with="Saving...">Save Invoice</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"invoice" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"invoice" => params}, socket) do
    member = socket.assigns.current_member
    params = Map.put(params, "organisation_id", member.organisation_id)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, invoice} ->
        notify_parent({:saved, invoice})

        {:noreply,
         socket
         |> put_flash(:info, "Invoice saved.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{invoice: nil}} = socket) do
    member = socket.assigns.current_member

    form =
      Form.for_create(CRM.Invoice, :create,
        as: "invoice",
        actor: member,
        tenant: member.organisation_id
      )

    assign(socket, :form, form)
  end

  defp assign_form(%{assigns: %{invoice: invoice}} = socket) do
    member = socket.assigns.current_member

    form =
      Form.for_update(invoice, :update,
        as: "invoice",
        actor: member,
        tenant: member.organisation_id
      )

    assign(socket, :form, form)
  end

  defp customer_options(member) do
    CRM.list_customers!(actor: member, tenant: member.organisation_id)
    |> Enum.map(fn c -> {"#{c.first_name} #{c.last_name}", c.id} end)
  rescue
    _ -> []
  end

  defp engagement_options(member) do
    CRM.list_engagements!(actor: member, tenant: member.organisation_id)
    |> Enum.map(fn e -> {e.title || e.id, e.id} end)
  rescue
    _ -> []
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
