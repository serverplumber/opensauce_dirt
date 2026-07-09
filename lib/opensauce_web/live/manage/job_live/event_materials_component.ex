defmodule OpenSauceWeb.JobLive.EventMaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Inventory
  alias OpenSauce.Work

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-direction:column;gap:16px;">
      <div
        :if={@event_materials != []}
        style="border:1px solid rgba(52,48,37,0.58);border-radius:12px;overflow:hidden;"
      >
        <div
          :for={jem <- @event_materials}
          style="display:flex;align-items:center;justify-content:space-between;padding:11px 14px;border-bottom:1px solid rgba(52,48,37,0.58);"
        >
          <div>
            <p style="font-size:13px;font-weight:600;color:#F4EFE2;">{jem.material.name}</p>
            <p style="font-size:12px;color:#9A9384;">{jem.quantity} {jem.material.unit}</p>
          </div>
          <button
            type="button"
            phx-click="remove"
            phx-value-id={jem.id}
            phx-target={@myself}
            ontouchstart=""
            style="font-size:12px;font-weight:600;color:#E87E7E;background:none;border:none;padding:4px 8px;cursor:pointer;flex-shrink:0;"
          >
            Remove
          </button>
        </div>
      </div>
      <p :if={@event_materials == []} style="font-size:13px;color:#6E675A;padding:4px 0;">
        No materials logged for this event yet.
      </p>

      <div style="display:flex;justify-content:flex-end;padding-top:2px;">
        <span style="font-size:12px;color:#9A9384;margin-right:8px;">Total cost</span>
        <span style="font-size:12px;font-weight:600;color:#F4EFE2;">
          {format_money(@currency, @total_cost)}
        </span>
      </div>

      <div style="border-top:1px solid rgba(52,48,37,0.58);padding-top:16px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:12px;">
          Add material
        </p>
        <.form
          for={@form}
          id="event-material-add-form"
          phx-target={@myself}
          phx-submit="add"
          style="display:flex;flex-direction:column;gap:12px;"
        >
          <div style="display:flex;gap:10px;">
            <div style="flex:2;">
              <p class="dark-label">Material</p>
              <select name="event_material[material_id]" class="dark-select">
                <option value="">Select a material</option>
                <option
                  :for={m <- @materials}
                  value={m.id}
                  selected={@form[:material_id].value == m.id}
                >
                  {material_label(m)}
                </option>
              </select>
            </div>
            <div style="flex:1;">
              <p class="dark-label">Quantity</p>
              <input
                type="number"
                name="event_material[quantity]"
                value={@form[:quantity].value}
                step="0.01"
                min="0"
                class="dark-input"
                style="width:100%;"
              />
            </div>
          </div>
          <button
            type="submit"
            phx-disable-with="Adding…"
            ontouchstart=""
            style="width:100%;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
          >
            Add
          </button>
        </.form>
      </div>

      <div style="border-top:1px solid rgba(52,48,37,0.58);padding-top:12px;display:flex;justify-content:flex-end;">
        <button
          type="button"
          phx-click="close_event_materials"
          ontouchstart=""
          style="background:none;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 20px;font-size:13px;font-weight:600;color:#9A9384;cursor:pointer;"
        >
          Done
        </button>
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

    case Work.log_job_event_material(
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
        msg = Enum.map_join(err.errors, ", ", & &1.message)
        {:noreply, put_flash(socket, :error, "Could not add material: #{msg}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add material.")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    jem = Enum.find(socket.assigns.event_materials, &(&1.id == id))

    case Work.destroy_job_event_material(jem, actor: member, tenant: member.organisation_id) do
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
    Work.list_job_event_materials!(
      event.id,
      actor: member,
      tenant: member.organisation_id,
      load: [:material]
    )
  end

  defp blank_form, do: to_form(%{"material_id" => "", "quantity" => ""}, as: "event_material")

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
