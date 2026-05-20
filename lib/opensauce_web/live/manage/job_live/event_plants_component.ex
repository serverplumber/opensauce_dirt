defmodule OpenSauceWeb.JobLive.EventPlantsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"jep-#{@job_event.id}"} rows={@plants}>
        <:col :let={jep} label="Role">{role_label(jep.role)}</:col>
        <:col :let={jep} label="Name">{jep.plant.name}</:col>
        <:col :let={jep} label="Form">{jep.plant.form || "—"}</:col>
        <:col :let={jep} label="Size">{jep.plant.size || "—"}</:col>
        <:action :let={jep}>
          <.button
            variant={:outline}
            phx-click="remove"
            phx-value-id={jep.id}
            phx-target={@myself}
          >
            Remove
          </.button>
        </:action>
        <:empty>No plants logged for this event yet.</:empty>
      </.table>

      <div class="flex justify-end border-t border-stone-200 pt-2 text-sm">
        <span class="text-stone-500 mr-2">Plant cost</span>
        <span class="font-medium">{format_money(@currency, @total_cost)}</span>
      </div>

      <div class="border-t border-stone-200 pt-4">
        <h4 class="mb-3 text-sm font-medium text-stone-700">Add plant</h4>
        <.simple_form for={@form} id="event-plant-add-form" phx-target={@myself} phx-submit="add">
          <div class="space-y-3">
            <div class="grid grid-cols-2 gap-3">
              <.input field={@form[:name]} label="Name" />
              <.input
                field={@form[:role]}
                type="select"
                label="Role"
                options={[
                  {"— select —", ""},
                  {"Install", "install"},
                  {"Propagate", "propagate"},
                  {"Harvest", "harvest"},
                  {"Pickup", "pickup"},
                  {"Dropoff", "dropoff"},
                  {"Reception", "reception"}
                ]}
              />
            </div>
            <div class="grid grid-cols-3 gap-3">
              <.input
                field={@form[:form]}
                type="select"
                label="Form"
                options={[
                  {"— select —", ""},
                  {"Seed", "seed"},
                  {"Bulb", "bulb"},
                  {"Division", "division"},
                  {"Cutting", "cutting"},
                  {"Specimen", "specimen"}
                ]}
              />
              <.input field={@form[:size]} label="Size" />
              <.input field={@form[:cost]} type="number" label="Cost" step="0.01" min="0" />
            </div>
            <.input field={@form[:note]} label="Note" />
          </div>
          <:actions>
            <.button variant={:primary} phx-disable-with="Adding...">Add plant</.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="flex justify-end border-t border-stone-200 pt-4">
        <.button phx-click="close_event_plants">Done</.button>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{job_event: _job_event, current_member: _member} = assigns, socket) do
    plants = load_plants(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:plants, plants)
     |> assign(:total_cost, sum_plants_cost(plants))
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("add", %{"plant" => params}, socket) do
    member = socket.assigns.current_member
    event = socket.assigns.job_event
    date = DateTime.to_date(event.timestamp)

    with {:ok, plant} <-
           CRM.create_plant(
             %{
               name: params["name"],
               form: parse_atom(params["form"]),
               size: nilify(params["size"]),
               cost: parse_decimal(params["cost"]),
               note: nilify(params["note"])
             },
             actor: member,
             tenant: member.organisation_id
           ),
         {:ok, _jep} <-
           Orders.log_job_event_plant(
             %{
               job_event_id: event.id,
               plant_id: plant.id,
               role: parse_atom(params["role"]),
               date: date
             },
             actor: member,
             tenant: member.organisation_id
           ) do
      plants = load_plants(socket.assigns)

      {:noreply,
       socket
       |> assign(:plants, plants)
       |> assign(:total_cost, sum_plants_cost(plants))
       |> assign(:form, blank_form())}
    else
      {:error, %Ash.Error.Invalid{} = err} ->
        msg = err.errors |> Enum.map(& &1.message) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Could not add plant: #{msg}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add plant.")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    jep = Enum.find(socket.assigns.plants, &(&1.id == id))

    case Orders.destroy_job_event_plant(jep, actor: member, tenant: member.organisation_id) do
      :ok ->
        plants = load_plants(socket.assigns)

        {:noreply,
         socket
         |> assign(:plants, plants)
         |> assign(:total_cost, sum_plants_cost(plants))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove plant.")}
    end
  end

  defp load_plants(%{job_event: event, current_member: member}) do
    Orders.list_job_event_plants!(
      event.id,
      actor: member,
      tenant: member.organisation_id,
      load: [:plant]
    )
  end

  defp blank_form,
    do:
      to_form(
        %{"name" => "", "role" => "", "form" => "", "size" => "", "cost" => "", "note" => ""},
        as: "plant"
      )

  defp role_label(:install), do: "Install"
  defp role_label(:propagate), do: "Propagate"
  defp role_label(:harvest), do: "Harvest"
  defp role_label(:pickup), do: "Pickup"
  defp role_label(:dropoff), do: "Dropoff"
  defp role_label(:reception), do: "Reception"
  defp role_label(other), do: to_string(other)

  defp nilify(""), do: nil
  defp nilify(s), do: s

  defp parse_atom(""), do: nil
  defp parse_atom(s), do: String.to_existing_atom(s)

  defp parse_decimal(""), do: nil

  defp parse_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp sum_plants_cost(plants) do
    Enum.reduce(plants, Decimal.new(0), fn jep, acc ->
      cost = (jep.plant && jep.plant.cost) || Decimal.new(0)
      Decimal.add(acc, cost)
    end)
  end
end
