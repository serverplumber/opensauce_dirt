# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.InventoryLive.FormComponentMovement do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias Decimal, as: D
  alias OpenSauce.Inventory
  alias OpenSauce.Types.Unit

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:mode, fn -> :add end)
     |> assign_new(:calculated_new_total, fn -> nil end)
     |> assign_new(:form, fn -> build_form(assigns.current_member) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-direction:column;gap:16px;">
      <%!-- current stock --%>
      <div style="background:rgba(84,181,126,0.08);border:1px solid rgba(84,181,126,0.2);border-radius:12px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between;">
        <span style="font-size:12px;font-weight:700;letter-spacing:0.04em;text-transform:uppercase;color:#6E675A;">
          Current stock
        </span>
        <span style="font-size:15px;font-weight:700;color:#54B57E;">
          {format_amount(@material.unit, @material.current_stock)}
        </span>
      </div>

      <%!-- add / subtract toggle --%>
      <div style="display:flex;gap:0;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:13px;padding:4px;">
        <button
          type="button"
          phx-click="set_mode"
          phx-value-mode="add"
          phx-target={@myself}
          ontouchstart=""
          class={["seg-tab", @mode == :add && "seg-tab--on"]}
          style="flex:1;"
        >
          Add
        </button>
        <button
          type="button"
          phx-click="set_mode"
          phx-value-mode="subtract"
          phx-target={@myself}
          ontouchstart=""
          class={["seg-tab", @mode == :subtract && "seg-tab--on"]}
          style="flex:1;"
        >
          Subtract
        </button>
      </div>

      <form
        id="movement-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        style="display:flex;flex-direction:column;gap:16px;"
      >
        <input type="hidden" name={@form[:material_id].name} value={@material.id} />

        <div>
          <label class="dark-label" for={@form[:quantity].id}>
            {if @mode == :add, do: "Quantity to add", else: "Quantity to subtract"} ({unit_abbr(
              @material.unit
            )})
          </label>
          <input
            class="dark-input"
            type="number"
            id={@form[:quantity].id}
            name={@form[:quantity].name}
            value={@form[:quantity].value}
            min="0"
            step="any"
            placeholder="0"
          />
          <span :for={msg <- @form[:quantity].errors} class="dark-field-error">{elem(msg, 0)}</span>
        </div>

        <div>
          <label class="dark-label" for={@form[:reason].id}>Notes</label>
          <textarea
            class="dark-textarea"
            id={@form[:reason].id}
            name={@form[:reason].name}
            placeholder="Optional"
            rows="2"
          >{@form[:reason].value}</textarea>
          <span :for={msg <- @form[:reason].errors} class="dark-field-error">{elem(msg, 0)}</span>
        </div>

        <%!-- new total preview --%>
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between;">
          <span style="font-size:12px;color:#6E675A;">New stock</span>
          <span
            :if={@calculated_new_total}
            style={"font-size:15px;font-weight:700;#{if negative?(@calculated_new_total), do: "color:#E87E7E;", else: "color:#54B57E;"}"}
          >
            {format_amount(@material.unit, D.to_float(@calculated_new_total))}
          </span>
          <span :if={!@calculated_new_total} style="font-size:13px;color:#6E675A;">—</span>
        </div>

        <.glow_button valid={true} type="submit">Save</.glow_button>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)
    quantity = parse_quantity(socket.assigns.form.params["quantity"])

    {:noreply,
     socket
     |> assign(:mode, mode)
     |> assign(
       :calculated_new_total,
       new_total(socket.assigns.material.current_stock, mode, quantity)
     )}
  end

  @impl true
  def handle_event("validate", %{"movement" => params}, socket) do
    quantity = parse_quantity(params["quantity"])

    {:noreply,
     socket
     |> assign(:form, Form.validate(socket.assigns.form, params))
     |> assign(
       :calculated_new_total,
       new_total(socket.assigns.material.current_stock, socket.assigns.mode, quantity)
     )}
  end

  @impl true
  def handle_event("save", %{"movement" => params}, socket) do
    params = sign_quantity(params, socket.assigns.mode)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, movement} ->
        send(self(), {:saved, movement})

        {:noreply,
         socket
         |> put_flash(:info, "Stock adjustment recorded.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp new_total(_current, _mode, nil), do: nil
  defp new_total(current, :add, qty), do: D.add(current, qty)
  defp new_total(current, :subtract, qty), do: D.sub(current, qty)

  defp sign_quantity(params, :subtract) do
    case parse_quantity(params["quantity"]) do
      nil -> params
      qty -> Map.put(params, "quantity", D.to_string(D.negate(qty)))
    end
  end

  defp sign_quantity(params, :add), do: params

  defp parse_quantity(value) when is_binary(value) and value != "" do
    case D.parse(value) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp parse_quantity(_), do: nil

  defp negative?(value), do: D.compare(value, D.new(0)) == :lt

  defp unit_abbr(unit), do: Unit.abbreviation(unit)

  defp build_form(current_member) do
    Inventory.Movement
    |> Form.for_create(:adjust_stock,
      as: "movement",
      actor: current_member,
      tenant: current_member.organisation_id
    )
    |> to_form()
  end
end
