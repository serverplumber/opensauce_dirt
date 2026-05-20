defmodule OpenSauceWeb.JobLive.MaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Inventory
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"jm-#{@job_id}"} rows={@job_materials}>
        <:col :let={jm} label="Material">{jm.material.name}</:col>
        <:col :let={jm} label="Qty">{jm.quantity} {jm.material.unit}</:col>
        <:action :let={jm}>
          <.button
            variant={:outline}
            phx-click="remove"
            phx-value-id={jm.id}
            phx-target={@myself}
            data-confirm="Remove this material from the job?"
          >
            Remove
          </.button>
        </:action>
        <:empty>No materials on this job yet.</:empty>
      </.table>

      <div class="flex justify-end border-t border-stone-200 pt-2 text-sm">
        <span class="text-stone-500 mr-2">Total cost</span>
        <span class="font-medium">{format_money(@currency, @total_cost)}</span>
      </div>

      <div class="border-t border-stone-200 pt-4">
        <h4 class="mb-3 text-sm font-medium text-stone-700">Add material</h4>
        <.simple_form for={@form} id="job-material-add-form" phx-target={@myself} phx-submit="add">
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
    </div>
    """
  end

  @impl true
  def update(%{job_id: _job_id, current_member: member} = assigns, socket) do
    materials =
      Inventory.list_materials!(
        actor: member,
        tenant: member.organisation_id
      )

    job_materials = load_job_materials(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:materials, materials)
     |> assign(:job_materials, job_materials)
     |> assign(:total_cost, sum_materials_cost(job_materials))
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("add", %{"job_material" => params}, socket) do
    member = socket.assigns.current_member

    case Orders.create_job_material(
           %{
             job_id: socket.assigns.job_id,
             material_id: params["material_id"],
             quantity: parse_decimal(params["quantity"])
           },
           actor: member,
           tenant: member.organisation_id
         ) do
      {:ok, _jm} ->
        job_materials = load_job_materials(socket.assigns)

        {:noreply,
         socket
         |> assign(:job_materials, job_materials)
         |> assign(:total_cost, sum_materials_cost(job_materials))
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
    jm = Enum.find(socket.assigns.job_materials, &(&1.id == id))

    case Orders.destroy_job_material(jm, actor: member, tenant: member.organisation_id) do
      :ok ->
        job_materials = load_job_materials(socket.assigns)

        {:noreply,
         socket
         |> assign(:job_materials, job_materials)
         |> assign(:total_cost, sum_materials_cost(job_materials))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove material.")}
    end
  end

  defp load_job_materials(%{job_id: job_id, current_member: member}) do
    Orders.get_job_by_id!(
      job_id,
      actor: member,
      tenant: member.organisation_id,
      load: [materials: [:material]]
    ).materials
  end

  defp blank_form,
    do: to_form(%{"material_id" => "", "quantity" => ""}, as: "job_material")

  defp parse_decimal(""), do: nil

  defp parse_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp sum_materials_cost(job_materials) do
    Enum.reduce(job_materials, Decimal.new(0), fn jm, acc ->
      price = (jm.material && jm.material.price) || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(jm.quantity, price))
    end)
  end

  defp material_label(m), do: "#{m.name} (#{m.unit})"
end
