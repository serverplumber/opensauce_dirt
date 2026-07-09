# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.InventoryLive.FormComponentMaterial do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    unit = assigns.form[:unit].value || :gram

    assigns = assign(assigns, :unit, unit)

    ~H"""
    <form
      id="material-form"
      phx-change="validate"
      phx-submit="save"
      phx-target={@myself}
      style="display:flex;flex-direction:column;gap:16px;"
    >
      <div>
        <label class="dark-label" for={@form[:name].id}>Name</label>
        <input
          class="dark-input"
          type="text"
          id={@form[:name].id}
          name={@form[:name].name}
          value={@form[:name].value}
          placeholder="Slow-release fertiliser"
        />
        <span :for={msg <- @form[:name].errors} class="dark-field-error">{elem(msg, 0)}</span>
      </div>

      <div>
        <label class="dark-label" for={@form[:sku].id}>SKU</label>
        <input
          class="dark-input"
          type="text"
          id={@form[:sku].id}
          name={@form[:sku].name}
          value={@form[:sku].value}
          placeholder="FERT-001"
        />
        <span :for={msg <- @form[:sku].errors} class="dark-field-error">{elem(msg, 0)}</span>
      </div>

      <div>
        <label class="dark-label" for={@form[:material_type].id}>Type</label>
        <select class="dark-select" id={@form[:material_type].id} name={@form[:material_type].name}>
          <option value="supply" selected={@form[:material_type].value == :supply}>Supply</option>
          <option value="plant" selected={@form[:material_type].value == :plant}>Plant</option>
        </select>
        <span :for={msg <- @form[:material_type].errors} class="dark-field-error">
          {elem(msg, 0)}
        </span>
      </div>

      <div>
        <label class="dark-label" for={@form[:unit].id}>Unit</label>
        <select class="dark-select" id={@form[:unit].id} name={@form[:unit].name}>
          <option value="gram" selected={@form[:unit].value == :gram}>Gram (g)</option>
          <option value="milliliter" selected={@form[:unit].value == :milliliter}>
            Milliliter (mL)
          </option>
          <option value="piece" selected={@form[:unit].value == :piece}>Piece (pcs)</option>
        </select>
        <span :for={msg <- @form[:unit].errors} class="dark-field-error">{elem(msg, 0)}</span>
      </div>

      <div>
        <label class="dark-label" for={@form[:price].id}>Price per {unit_abbr(@unit)}</label>
        <input
          class="dark-input"
          type="number"
          id={@form[:price].id}
          name={@form[:price].name}
          value={@form[:price].value}
          step="0.001"
          min="0"
          placeholder="0.00"
        />
        <span :for={msg <- @form[:price].errors} class="dark-field-error">{elem(msg, 0)}</span>
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div>
          <label class="dark-label" for={@form[:minimum_stock].id}>
            Min stock ({unit_abbr(@unit)})
          </label>
          <input
            class="dark-input"
            type="number"
            id={@form[:minimum_stock].id}
            name={@form[:minimum_stock].name}
            value={@form[:minimum_stock].value}
            step="0.001"
            min="0"
            placeholder="0"
          />
          <span :for={msg <- @form[:minimum_stock].errors} class="dark-field-error">
            {elem(msg, 0)}
          </span>
        </div>
        <div>
          <label class="dark-label" for={@form[:maximum_stock].id}>
            Max stock ({unit_abbr(@unit)})
          </label>
          <input
            class="dark-input"
            type="number"
            id={@form[:maximum_stock].id}
            name={@form[:maximum_stock].name}
            value={@form[:maximum_stock].value}
            step="0.001"
            min="0"
            placeholder="0"
          />
          <span :for={msg <- @form[:maximum_stock].errors} class="dark-field-error">
            {elem(msg, 0)}
          </span>
        </div>
      </div>

      <div :if={@catalog_items != []}>
        <label class="dark-label">Default supplier</label>
        <select
          id={@form[:default_supplier_catalog_item_id].id}
          name={@form[:default_supplier_catalog_item_id].name}
          class="dark-select"
          style={
            if @form[:default_supplier_catalog_item_id].value in [nil, ""],
              do: "color:#6E675A;",
              else: "color:#F4EFE2;"
          }
        >
          <option value="">— none —</option>
          <option
            :for={sci <- @catalog_items}
            value={sci.id}
            selected={@form[:default_supplier_catalog_item_id].value == sci.id}
          >
            {sci_label(sci)}
          </option>
        </select>
      </div>

      <.glow_button valid={form_valid?(@form)} type="submit">Save material</.glow_button>
    </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_new(:catalog_items, fn -> [] end) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"material" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"material" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, material} ->
        send(self(), {:saved, material})

        {:noreply,
         socket
         |> put_flash(:info, "Material #{socket.assigns.form.source.type}d.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{material: material}} = socket) do
    opts = [
      as: "material",
      actor: socket.assigns.current_member,
      tenant: socket.assigns.current_member.organisation_id
    ]

    form =
      if material do
        Form.for_update(material, :update, opts)
      else
        Form.for_create(Inventory.Material, :create, opts)
      end

    assign(socket, form: to_form(form))
  end

  defp form_valid?(form) do
    form[:name].value not in [nil, ""] and
      form[:sku].value not in [nil, ""] and
      form[:price].value not in [nil, ""]
  end

  defp unit_abbr(:gram), do: "g"
  defp unit_abbr(:milliliter), do: "mL"
  defp unit_abbr(:piece), do: "pcs"
  defp unit_abbr(_), do: ""

  defp sci_label(%{latin_name: ln, cultivar: cv, supplier_catalog: %{supplier: %{name: sn}}}) when not is_nil(ln) do
    title = [ln, cv] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
    "#{sn} — #{title}"
  end

  defp sci_label(%{name: name, supplier_catalog: %{supplier: %{name: sn}}}) when not is_nil(name), do: "#{sn} — #{name}"

  defp sci_label(%{sku: sku, supplier_catalog: %{supplier: %{name: sn}}}) when not is_nil(sku), do: "#{sn} — #{sku}"

  defp sci_label(%{sku: sku}) when not is_nil(sku), do: sku
  defp sci_label(_), do: "—"
end
