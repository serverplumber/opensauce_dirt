defmodule OpenSauceWeb.EngagementLive.MaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"em-#{@engagement_id}"} rows={@engagement_materials}>
        <:col :let={em} label="Material">{em.material.name}</:col>
        <:col :let={em} label="Unit">{em.material.unit}</:col>
        <:col :let={em} label="Qty">{em.quantity}</:col>
        <:col :let={em} label="Scheduled">{format_date(em.scheduled_date) || "—"}</:col>
        <:col :let={em} label="Note">{em.note || "—"}</:col>
        <:action :let={em}>
          <.button
            variant={:outline}
            phx-click="remove"
            phx-value-id={em.id}
            phx-target={@myself}
          >
            Remove
          </.button>
        </:action>
        <:empty>No materials on this engagement yet.</:empty>
      </.table>

      <div class="flex justify-end border-t border-stone-200 pt-2 text-sm">
        <span class="text-stone-500 mr-2">Material cost</span>
        <span class="font-medium">{format_money(@currency, @total_cost)}</span>
      </div>

      <div class="border-t border-stone-200 pt-4">
        <h4 class="mb-3 text-sm font-medium text-stone-700">Add material</h4>
        <.simple_form
          for={@form}
          id="engagement-material-add-form"
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
          <div class="grid grid-cols-2 gap-3">
            <.input field={@form[:scheduled_date]} type="date" label="Scheduled date" />
            <.input field={@form[:note]} label="Note" />
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
  def update(%{engagement_id: _engagement_id, current_member: member} = assigns, socket) do
    materials =
      Inventory.list_materials!(
        actor: member,
        tenant: member.organisation_id
      )

    engagement_materials = load_engagement_materials(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:materials, materials)
     |> assign(:engagement_materials, engagement_materials)
     |> assign(:total_cost, sum_cost(engagement_materials))
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("add", %{"engagement_material" => params}, socket) do
    member = socket.assigns.current_member

    case CRM.create_engagement_material(
           %{
             engagement_id: socket.assigns.engagement_id,
             material_id: params["material_id"],
             quantity: parse_decimal(params["quantity"]),
             scheduled_date: parse_date(params["scheduled_date"]),
             note: nilify(params["note"])
           },
           actor: member,
           tenant: member.organisation_id
         ) do
      {:ok, _em} ->
        engagement_materials = load_engagement_materials(socket.assigns)

        {:noreply,
         socket
         |> assign(:engagement_materials, engagement_materials)
         |> assign(:total_cost, sum_cost(engagement_materials))
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
    em = Enum.find(socket.assigns.engagement_materials, &(&1.id == id))

    case CRM.destroy_engagement_material(em, actor: member, tenant: member.organisation_id) do
      :ok ->
        engagement_materials = load_engagement_materials(socket.assigns)

        {:noreply,
         socket
         |> assign(:engagement_materials, engagement_materials)
         |> assign(:total_cost, sum_cost(engagement_materials))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove material.")}
    end
  end

  defp load_engagement_materials(%{engagement_id: engagement_id, current_member: member}) do
    CRM.get_engagement_by_id!(
      engagement_id,
      actor: member,
      tenant: member.organisation_id,
      load: [materials: [:material]]
    ).materials
  end

  defp blank_form,
    do:
      to_form(
        %{"material_id" => "", "quantity" => "", "scheduled_date" => "", "note" => ""},
        as: "engagement_material"
      )

  defp parse_date(""), do: nil

  defp parse_date(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp nilify(""), do: nil
  defp nilify(s), do: s

  defp parse_decimal(""), do: nil

  defp parse_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp sum_cost(engagement_materials) do
    Enum.reduce(engagement_materials, Decimal.new(0), fn em, acc ->
      price = (em.material && em.material.price) || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(em.quantity, price))
    end)
  end

  defp material_label(m), do: "#{m.name} (#{m.unit})"
end
