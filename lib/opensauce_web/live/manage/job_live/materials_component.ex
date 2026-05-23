defmodule OpenSauceWeb.JobLive.MaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Orders
  alias OpenSauceWeb.CatalogSearchComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"jm-#{@job_id}"} rows={@job_materials}>
        <:col :let={jm} label="Plant">
          <span class="italic">{catalog_item_title(jm.supplier_catalog_item)}</span>
        </:col>
        <:col :let={jm} label="Format">
          {jm.supplier_catalog_item.format_description || "—"}
        </:col>
        <:col :let={jm} label="Supplier">
          {jm.supplier_catalog_item.supplier_catalog.supplier.name}
        </:col>
        <:col :let={jm} label="Qty">{jm.quantity}</:col>
        <:action :let={jm}>
          <.button
            variant={:outline}
            phx-click="remove"
            phx-value-id={jm.id}
            phx-target={@myself}
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

        <div class="mb-3">
          <label class="mb-1 block text-sm font-medium text-stone-700">Search Catalog</label>
          <.live_component
            module={CatalogSearchComponent}
            id={"jm-catalog-search-#{@id}"}
            current_member={@current_member}
            notify={__MODULE__}
            notify_id={@id}
            selected_item={@selected_item}
          />
        </div>

        <.simple_form for={@form} id="job-material-add-form" phx-target={@myself} phx-submit="add">
          <input
            type="hidden"
            name="job_material[supplier_catalog_item_id]"
            value={@selected_item && @selected_item.id}
          />
          <.input field={@form[:quantity]} type="number" label="Quantity" step="0.01" min="0" />
          <:actions>
            <.button
              variant={:primary}
              phx-disable-with="Adding..."
              disabled={is_nil(@selected_item)}
            >
              Add
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{catalog_item: item} = _assigns, socket) do
    {:ok, assign(socket, :selected_item, item)}
  end

  def update(%{job_id: _job_id, current_member: _member} = assigns, socket) do
    job_materials = load_job_materials(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:job_materials, job_materials)
     |> assign(:total_cost, sum_materials_cost(job_materials))
     |> assign_new(:selected_item, fn -> nil end)
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("add", %{"job_material" => params}, socket) do
    member = socket.assigns.current_member

    case Orders.create_job_material(
           %{
             job_id: socket.assigns.job_id,
             supplier_catalog_item_id: params["supplier_catalog_item_id"],
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
         |> assign(:selected_item, nil)
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
      load: [materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]]
    ).materials
  end

  defp blank_form,
    do: to_form(%{"supplier_catalog_item_id" => "", "quantity" => ""}, as: "job_material")

  defp parse_decimal(""), do: nil

  defp parse_decimal(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp sum_materials_cost(job_materials) do
    Enum.reduce(job_materials, Decimal.new(0), fn jm, acc ->
      price =
        (jm.supplier_catalog_item && jm.supplier_catalog_item.unit_price) || Decimal.new(0)

      Decimal.add(acc, Decimal.mult(jm.quantity, price))
    end)
  end

  defp catalog_item_title(item) do
    [item.latin_name, item.cultivar]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> item.name
      title -> title
    end
  end
end
