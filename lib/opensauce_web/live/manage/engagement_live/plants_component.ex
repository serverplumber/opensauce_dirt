defmodule OpenSauceWeb.EngagementLive.PlantsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"ep-#{@engagement_id}"} rows={@plants}>
        <:col :let={ep} label="Name">{ep.plant.name}</:col>
        <:col :let={ep} label="Form">{ep.plant.form || "—"}</:col>
        <:col :let={ep} label="Size">{ep.plant.size || "—"}</:col>
        <:col :let={ep} label="Cost">{ep.plant.cost || "—"}</:col>
        <:col :let={ep} label="Scheduled">{format_date(ep.date) || "—"}</:col>
        <:action :let={ep}>
          <.button
            variant={:outline}
            phx-click="remove"
            phx-value-id={ep.id}
            phx-target={@myself}
          >
            Remove
          </.button>
        </:action>
        <:empty>No plants scheduled yet.</:empty>
      </.table>

      <div class="flex justify-end border-t border-stone-200 pt-2 text-sm">
        <span class="text-stone-500 mr-2">Plant cost</span>
        <span class="font-medium">{format_money(@currency, @total_cost)}</span>
      </div>

      <div class="border-t border-stone-200 pt-4">
        <h4 class="mb-3 text-sm font-medium text-stone-700">Add plant</h4>
        <.simple_form for={@form} id="plant-add-form" phx-target={@myself} phx-submit="add">
          <div class="space-y-3">
            <div class="grid grid-cols-2 gap-3">
              <.input field={@form[:name]} label="Name" />
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
            </div>
            <div class="grid grid-cols-3 gap-3">
              <.input field={@form[:size]} label="Size" />
              <.input field={@form[:cost]} type="number" label="Cost" step="0.01" min="0" />
              <.input field={@form[:date]} type="date" label="Scheduled" />
            </div>
            <.input field={@form[:note]} label="Note" />
          </div>
          <:actions>
            <.button variant={:primary} phx-disable-with="Adding...">Add plant</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{engagement_id: _engagement_id, current_member: _member} = assigns, socket) do
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
         {:ok, _ep} <-
           CRM.create_engagement_plant(
             %{
               engagement_id: socket.assigns.engagement_id,
               plant_id: plant.id,
               date: parse_date(params["date"])
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
    ep = Enum.find(socket.assigns.plants, &(&1.id == id))

    case CRM.destroy_engagement_plant(ep,
           actor: member,
           tenant: member.organisation_id
         ) do
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

  defp load_plants(%{engagement_id: engagement_id, current_member: member}) do
    CRM.get_engagement_by_id!(
      engagement_id,
      actor: member,
      tenant: member.organisation_id,
      load: [plants: [:plant]]
    ).plants
  end

  defp blank_form,
    do:
      to_form(
        %{"name" => "", "form" => "", "size" => "", "cost" => "", "note" => "", "date" => ""},
        as: "plant"
      )

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

  defp parse_date(""), do: nil

  defp parse_date(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp sum_plants_cost(plants) do
    Enum.reduce(plants, Decimal.new(0), fn ep, acc ->
      cost = (ep.plant && ep.plant.cost) || Decimal.new(0)
      Decimal.add(acc, cost)
    end)
  end
end
