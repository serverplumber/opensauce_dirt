defmodule OpenSauceWeb.JobLive.EventMaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Inventory
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"jem-#{@job_event.id}"} rows={@event_materials}>
        <:col :let={jem} label="Material">{jem.material.name}</:col>
        <:col :let={jem} label="Qty">{jem.quantity} {jem.material.unit}</:col>
        <:action :let={jem}>
          <.button
            variant={:outline}
            phx-click="remove"
            phx-value-id={jem.id}
            phx-target={@myself}
          >
            Remove
          </.button>
        </:action>
        <:empty>No materials logged for this event yet.</:empty>
      </.table>

      <div class="flex justify-end border-t border-stone-200 pt-2 text-sm">
        <span class="text-stone-500 mr-2">Total cost</span>
        <span class="font-medium">{format_money(@currency, @total_cost)}</span>
      </div>

      <div class="border-t border-stone-200 pt-4">
        <h4 class="mb-3 text-sm font-medium text-stone-700">Add material</h4>
        <.simple_form
          for={@form}
          id="event-material-add-form"
          phx-target={@myself}
          phx-submit="add"
        >
          <div class="grid grid-cols-3 gap-3">
            <div class="col-span-2">
              <.input
                field={@form[:material_id]}
                type="select"
                label="Material"
                options={Enum.map(@materials, &{material_label(&1), &1.id})}
                prompt="Select a material"
              />
            </div>
            <.input field={@form[:quantity]} type="number" label="Quantity" step="0.01" min="0" />
          </div>
          <:actions>
            <.button variant={:primary} phx-disable-with="Adding...">Add</.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="flex justify-end border-t border-stone-200 pt-4">
        <.button phx-click="close_event_materials">Done</.button>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{job_event: _job_event, current_member: member} = assigns, socket) do
    materials =
      Inventory.list_materials!(
        actor: member,
        tenant: member.organisation_id
      )

    event_materials = load_event_materials(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:materials, materials)
     |> assign(:event_materials, event_materials)
     |> assign(:total_cost, sum_materials_cost(event_materials))
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("add", %{"event_material" => params}, socket) do
    member = socket.assigns.current_member

    case Orders.log_job_event_material(
           %{
             job_event_id: socket.assigns.job_event.id,
             material_id: params["material_id"],
             quantity: parse_decimal(params["quantity"])
           },
           actor: member,
           tenant: member.organisation_id
         ) do
      {:ok, _jem} ->
        event_materials = load_event_materials(socket.assigns)

        {:noreply,
         socket
         |> assign(:event_materials, event_materials)
         |> assign(:total_cost, sum_materials_cost(event_materials))
         |> assign(:form, blank_form())}

      {:error, %Ash.Error.Invalid{} = err} ->
        msg = err.errors |> Enum.map(& &1.message) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Could not add material: #{msg}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add material.")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    jem = Enum.find(socket.assigns.event_materials, &(&1.id == id))

    case Orders.destroy_job_event_material(jem, actor: member, tenant: member.organisation_id) do
      :ok ->
        event_materials = load_event_materials(socket.assigns)

        {:noreply,
         socket
         |> assign(:event_materials, event_materials)
         |> assign(:total_cost, sum_materials_cost(event_materials))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove material.")}
    end
  end

  defp load_event_materials(%{job_event: event, current_member: member}) do
    Orders.list_job_event_materials!(
      event.id,
      actor: member,
      tenant: member.organisation_id,
      load: [:material]
    )
  end

  defp blank_form,
    do: to_form(%{"material_id" => "", "quantity" => ""}, as: "event_material")

  defp parse_decimal(""), do: nil

  defp parse_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp sum_materials_cost(event_materials) do
    Enum.reduce(event_materials, Decimal.new(0), fn jem, acc ->
      price = (jem.material && jem.material.price) || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(jem.quantity, price))
    end)
  end

  defp material_label(m), do: "#{m.name} (#{m.unit})"
end
