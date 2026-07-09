defmodule OpenSauceWeb.JobLive.MaterialsComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Work
  alias OpenSauceWeb.CatalogSearchComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-direction:column;gap:16px;">
      <div
        :if={@job_materials != []}
        style="border:1px solid rgba(52,48,37,0.58);border-radius:12px;overflow:hidden;"
      >
        <div
          :for={jm <- @job_materials}
          style="display:flex;align-items:center;justify-content:space-between;padding:11px 14px;border-bottom:1px solid rgba(52,48,37,0.58);"
        >
          <div style="min-width:0;flex:1;margin-right:12px;">
            <p style="font-size:13px;font-weight:600;color:#F4EFE2;font-style:italic;">
              {catalog_item_title(jm.supplier_catalog_item)}
            </p>
            <p style="font-size:12px;color:#9A9384;margin-top:2px;">
              {jm.supplier_catalog_item.format_description || "—"} · {jm.supplier_catalog_item.supplier_catalog.supplier.name} · qty {jm.quantity}
            </p>
          </div>
          <button
            type="button"
            phx-click="remove"
            phx-value-id={jm.id}
            phx-target={@myself}
            ontouchstart=""
            style="font-size:12px;font-weight:600;color:#E87E7E;background:none;border:none;padding:4px 8px;cursor:pointer;flex-shrink:0;"
          >
            Remove
          </button>
        </div>
      </div>
      <p :if={@job_materials == []} style="font-size:13px;color:#6E675A;padding:4px 0;">
        No materials on this job yet.
      </p>

      <div style="display:flex;justify-content:flex-end;">
        <span style="font-size:12px;color:#9A9384;margin-right:8px;">Total cost</span>
        <span style="font-size:12px;font-weight:600;color:#F4EFE2;">
          {format_money(@currency, @total_cost)}
        </span>
      </div>

      <div style="border-top:1px solid rgba(52,48,37,0.58);padding-top:16px;display:flex;flex-direction:column;gap:12px;">
        <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
          Add material
        </p>
        <div>
          <p class="dark-label">Search Catalog</p>
          <.live_component
            module={CatalogSearchComponent}
            id={"jm-catalog-search-#{@id}"}
            current_member={@current_member}
            notify={__MODULE__}
            notify_id={@id}
            selected_item={@selected_item}
          />
        </div>
        <.form
          for={@form}
          id="job-material-add-form"
          phx-target={@myself}
          phx-submit="add"
          style="display:flex;flex-direction:column;gap:12px;"
        >
          <input
            type="hidden"
            name="job_material[supplier_catalog_item_id]"
            value={@selected_item && @selected_item.id}
          />
          <div>
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

    case Work.create_job_material(
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
        msg = Enum.map_join(err.errors, ", ", & &1.message)
        {:noreply, put_flash(socket, :error, "Could not add material: #{msg}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add material.")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    jm = Enum.find(socket.assigns.job_materials, &(&1.id == id))

    case Work.destroy_job_material(jm, actor: member, tenant: member.organisation_id) do
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
    Work.get_job_by_id!(
      job_id,
      actor: member,
      tenant: member.organisation_id,
      load: [materials: [supplier_catalog_item: [supplier_catalog: [:supplier]]]]
    ).materials
  end

  defp blank_form, do: to_form(%{"supplier_catalog_item_id" => "", "quantity" => ""}, as: "job_material")

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
