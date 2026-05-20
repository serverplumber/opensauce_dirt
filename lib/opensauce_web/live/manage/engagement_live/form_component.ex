defmodule OpenSauceWeb.EngagementLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="engagement-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-4">
          <.input
            field={@form[:garden_id]}
            type="select"
            label="Garden"
            options={Enum.map(@gardens, &{garden_label(&1), &1.id})}
            prompt="Select a garden"
          />

          <.input
            field={@form[:scope_description]}
            type="textarea"
            label="Scope"
            rows="4"
          />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:install_price]}
              type="number"
              label="Install price"
              step="0.01"
              min="0"
            />
            <.input
              field={@form[:maintenance_price_annual]}
              type="number"
              label="Annual maintenance"
              step="0.01"
              min="0"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:term_start]} type="date" label="Term start" />
            <.input field={@form[:term_end]} type="date" label="Term end" />
          </div>

          <.input
            field={@form[:status]}
            type="select"
            label="Status"
            options={[
              {"Draft", :draft},
              {"Proposed", :proposed},
              {"Signed", :signed},
              {"In progress", :in_progress},
              {"Completed", :completed},
              {"Cancelled", :cancelled}
            ]}
          />

          <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Engagement</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{engagement: engagement, customer: customer} = assigns, socket) do
    member = assigns.current_member

    form =
      if engagement do
        AshPhoenix.Form.for_update(engagement, :update,
          as: "engagement",
          actor: member,
          tenant: member.organisation_id
        )
      else
        AshPhoenix.Form.for_create(CRM.Engagement, :create,
          as: "engagement",
          actor: member,
          tenant: member.organisation_id
        )
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:customer_id, customer.id)
     |> assign(:gardens, customer.garden_addresses)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"engagement" => params}, socket) do
    params = Map.put(params, "customer_id", socket.assigns.customer_id)
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"engagement" => params}, socket) do
    params = Map.put(params, "customer_id", socket.assigns.customer_id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, engagement} ->
        notify_parent({:saved, engagement})

        {:noreply,
         socket
         |> put_flash(:info, "Engagement saved.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp garden_label(addr) do
    name = addr.name || "Garden"
    short = addr.short_address
    if short, do: "#{name} — #{short}", else: name
  end
end
