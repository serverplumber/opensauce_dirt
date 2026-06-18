defmodule OpenSauceWeb.EngagementLive.MaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauceWeb.CatalogSearchComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-direction:column;gap:16px;">
      <div
        :if={@engagement_materials != []}
        style="border:1px solid rgba(52,48,37,0.58);border-radius:12px;overflow:hidden;"
      >
        <div
          :for={em <- @engagement_materials}
          style="display:flex;align-items:flex-start;justify-content:space-between;padding:11px 14px;border-bottom:1px solid rgba(52,48,37,0.58);"
        >
          <div style="min-width:0;flex:1;margin-right:12px;">
            <p style="font-size:13px;font-weight:600;color:#F4EFE2;font-style:italic;">
              {catalog_item_title(em.supplier_catalog_item)}
            </p>
            <p style="font-size:12px;color:#9A9384;margin-top:2px;">
              {em.supplier_catalog_item.format_description || "—"} ·
              {em.supplier_catalog_item.supplier_catalog.supplier.name}
            </p>
            <p style="font-size:12px;color:#9A9384;margin-top:1px;">
              qty {em.quantity} · {format_date(em.scheduled_date) || "no date"}<span
                :if={em.note}
              > · {em.note}</span>
            </p>
          </div>
          <button
            type="button"
            phx-click="remove"
            phx-value-id={em.id}
            phx-target={@myself}
            ontouchstart=""
            style="font-size:12px;font-weight:600;color:#E87E7E;background:none;border:none;padding:4px 8px;cursor:pointer;flex-shrink:0;"
          >
            Remove
          </button>
        </div>
      </div>
      <p :if={@engagement_materials == []} style="font-size:13px;color:#6E675A;padding:4px 0;">
        No materials on this engagement yet.
      </p>

      <div style="display:flex;justify-content:flex-end;">
        <span style="font-size:12px;color:#9A9384;margin-right:8px;">Material cost</span>
        <span style="font-size:12px;font-weight:600;color:#F4EFE2;">{format_money(@currency, @total_cost)}</span>
      </div>

      <div style="border-top:1px solid rgba(52,48,37,0.58);padding-top:16px;display:flex;flex-direction:column;gap:12px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
          Add material
        </p>
        <div>
          <p class="dark-label">Search Catalog</p>
          <.live_component
            module={CatalogSearchComponent}
            id={"em-catalog-search-#{@id}"}
            current_member={@current_member}
            notify={__MODULE__}
            notify_id={@id}
            selected_item={@selected_item}
          />
        </div>
        <.form
          for={@form}
          id="engagement-material-add-form"
          phx-target={@myself}
          phx-submit="add"
          style="display:flex;flex-direction:column;gap:12px;"
        >
          <input
            type="hidden"
            name="engagement_material[supplier_catalog_item_id]"
            value={@selected_item && @selected_item.id}
          />
          <div style="display:flex;gap:10px;">
            <div style="flex:1;">
              <p class="dark-label">Quantity</p>
              <input
                type="number"
                id={@form[:quantity].id}
                name={@form[:quantity].name}
                value={@form[:quantity].value}
                step="0.01"
                min="0"
                class="dark-input"
                style="width:100%;"
              />
            </div>
            <div style="flex:1;">
              <p class="dark-label">Scheduled date</p>
              <input
                type="date"
                id={@form[:scheduled_date].id}
                name={@form[:scheduled_date].name}
                value={@form[:scheduled_date].value}
                class="dark-input"
                style="width:100%;"
              />
            </div>
          </div>
          <div>
            <p class="dark-label">Note</p>
            <input
              type="text"
              id={@form[:note].id}
              name={@form[:note].name}
              value={@form[:note].value}
              class="dark-input"
              style="width:100%;"
            />
          </div>
          <button
            type="submit"
            phx-disable-with="Adding…"
            disabled={is_nil(@selected_item)}
            ontouchstart=""
            style={"width:100%;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;cursor:pointer;#{if is_nil(@selected_item), do: "background:rgba(84,181,126,0.15);color:#54B57E;opacity:0.5;", else: "background:#54B57E;color:#0C1F15;"}"}
          >
            Add
          </button>
        </.form>
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
