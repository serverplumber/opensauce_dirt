# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.PurchasingLive.PurchaseOrderFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias AshPhoenix.Form
  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="purchase-order-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:16px;"
      >
        <div>
          <p class="dark-label">Supplier</p>
          <select
            id={@form[:supplier_id].id}
            name={@form[:supplier_id].name}
            class="dark-select"
          >
            <option value="">Select a supplier</option>
            <option
              :for={s <- @suppliers}
              value={s.id}
              selected={@form[:supplier_id].value == s.id}
            >
              {s.name}
            </option>
          </select>
        </div>

        <div>
          <p class="dark-label">Status</p>
          <select
            id={@form[:status].id}
            name={@form[:status].name}
            class="dark-select"
          >
            <option value="draft" selected={@form[:status].value in [:draft, "draft"]}>Draft</option>
            <option value="ordered" selected={@form[:status].value in [:ordered, "ordered"]}>Ordered</option>
            <option value="received" selected={@form[:status].value in [:received, "received"]}>Received</option>
          </select>
        </div>

        <div>
          <p class="dark-label">Ordered At</p>
          <input
            type="datetime-local"
            id={@form[:ordered_at].id}
            name={@form[:ordered_at].name}
            value={Phoenix.HTML.Form.normalize_value("datetime-local", @form[:ordered_at].value)}
            class="dark-input"
            style="width:100%;"
          />
        </div>

        <button
          type="submit"
          phx-disable-with="Saving…"
          ontouchstart=""
          style="width:100%;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
        >
          Save Purchase Order
        </button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"purchase_order" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"purchase_order" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, po} ->
        send(self(), {:po_saved, po})

        {:noreply,
         socket
         |> put_flash(:info, "Purchase order saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{purchase_order: po}} = socket) do
    form =
      if po do
        Form.for_update(po, :update,
          as: "purchase_order",
          actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id
        )
      else
        Form.for_create(Inventory.PurchaseOrder, :create,
          as: "purchase_order",
          actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id
        )
      end

    assign(socket, form: to_form(form))
  end
end
