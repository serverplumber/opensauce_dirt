defmodule OpenSauceWeb.EngagementLive.MaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauceWeb.CatalogSearchComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.table id={"em-#{@engagement_id}"} rows={@engagement_materials}>
        <:col :let={em} label="Plant">
          <span class="italic">{catalog_item_title(em.supplier_catalog_item)}</span>
        </:col>
        <:col :let={em} label="Format">
          {em.supplier_catalog_item.format_description || "—"}
        </:col>
        <:col :let={em} label="Supplier">
          {em.supplier_catalog_item.supplier_catalog.supplier.name}
        </:col>
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

        <div class="mb-3">
          <label class="mb-1 block text-sm font-medium text-stone-700">Search Catalog</label>
          <.live_component
            module={CatalogSearchComponent}
            id={"em-catalog-search-#{@id}"}
            current_member={@current_member}
            notify={__MODULE__}
            notify_id={@id}
            selected_item={@selected_item}
          />
        </div>

        <.simple_form
          for={@form}
          id="engagement-material-add-form"
          phx-target={@myself}
          phx-submit="add"
        >
          <input
            type="hidden"
            name="engagement_material[supplier_catalog_item_id]"
            value={@selected_item && @selected_item.id}
          />
          <div class="grid grid-cols-3 gap-3">
            <.input field={@form[:quantity]} type="number" label="Quantity" step="0.01" min="0" />
            <.input field={@form[:scheduled_date]} type="date" label="Scheduled date" />
            <.input field={@form[:note]} label="Note" />
          </div>
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

  def update(%{engagement_id: _engagement_id, current_member: _member} = assigns, socket) do
    engagement_materials = load_engagement_materials(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:engagement_materials, engagement_materials)
     |> assign(:total_cost, sum_cost(engagement_materials))
     |> assign_new(:selected_item, fn -> nil end)
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("add", %{"engagement_material" => params}, socket) do
    member = socket.assigns.current_member

    case CRM.create_engagement_material(
           %{
             engagement_id: socket.assigns.engagement_id,
             supplier_catalog_item_id: params["supplier_catalog_item_id"],
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
      load: [materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]]
    ).materials
  end

  defp blank_form,
    do:
      to_form(
        %{"supplier_catalog_item_id" => "", "quantity" => "", "scheduled_date" => "", "note" => ""},
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
      price = (em.supplier_catalog_item && em.supplier_catalog_item.unit_price) || Decimal.new(0)
      Decimal.add(acc, Decimal.mult(em.quantity, price))
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
