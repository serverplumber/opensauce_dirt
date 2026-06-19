# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.CustomerLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="customer-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:16px;"
      >
        <div style="display:flex;gap:8px;">
          <label style={"flex:1;display:flex;align-items:center;justify-content:center;padding:10px;border-radius:12px;cursor:pointer;font-size:14px;font-weight:600;#{if company_type?(@form), do: "background:rgba(84,181,126,0.12);border:1.5px solid rgba(84,181,126,0.4);color:#54B57E;", else: "background:#54B57E;border:1.5px solid #54B57E;color:#0C1F15;"}"}>
            <input
              type="radio"
              name={@form[:type].name}
              value="individual"
              checked={!company_type?(@form)}
              style="display:none;"
            />
            Individual
          </label>
          <label style={"flex:1;display:flex;align-items:center;justify-content:center;padding:10px;border-radius:12px;cursor:pointer;font-size:14px;font-weight:600;#{if company_type?(@form), do: "background:#54B57E;border:1.5px solid #54B57E;color:#0C1F15;", else: "background:rgba(84,181,126,0.12);border:1.5px solid rgba(84,181,126,0.4);color:#54B57E;"}"}>
            <input
              type="radio"
              name={@form[:type].name}
              value="company"
              checked={company_type?(@form)}
              style="display:none;"
            />
            Company
          </label>
        </div>

        <div style="display:flex;flex-direction:column;gap:12px;">
          <div>
            <p class="dark-label">{if company_type?(@form), do: "Company name", else: "Nickname"}</p>
            <input
              type="text"
              id={@form[:company_name_nickname].id}
              name={@form[:company_name_nickname].name}
              value={@form[:company_name_nickname].value}
              class="dark-input"
              style="width:100%;"
            />
          </div>
          <div style="display:flex;gap:10px;">
            <div style="flex:1;">
              <p class="dark-label">First name</p>
              <input
                type="text"
                id={@form[:first_name].id}
                name={@form[:first_name].name}
                value={@form[:first_name].value}
                class="dark-input"
                style="width:100%;"
              />
            </div>
            <div style="flex:1;">
              <p class="dark-label">Last name</p>
              <input
                type="text"
                id={@form[:last_name].id}
                name={@form[:last_name].name}
                value={@form[:last_name].value}
                class="dark-input"
                style="width:100%;"
              />
            </div>
          </div>
          <div>
            <p class="dark-label">Email</p>
            <input
              type="email"
              id={@form[:email].id}
              name={@form[:email].name}
              value={@form[:email].value}
              class="dark-input"
              style="width:100%;"
            />
          </div>
          <div>
            <p class="dark-label">Phone</p>
            <input
              type="tel"
              id={@form[:phone].id}
              name={@form[:phone].name}
              value={@form[:phone].value}
              class="dark-input"
              phx-hook="FormatPhone"
              style="width:100%;"
            />
          </div>
        </div>

        <button
          type="submit"
          phx-disable-with="Saving…"
          ontouchstart=""
          style="width:100%;background:#54B57E;border:none;border-radius:12px;padding:12px;font-size:14px;font-weight:700;color:#0C1F15;cursor:pointer;"
        >
          Save Customer
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
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, customer_params))}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: customer_params) do
      {:ok, customer} ->
        notify_parent({:saved, customer})

        {:noreply,
         socket
         |> put_flash(:info, "Customer #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp company_type?(form) do
    case Phoenix.HTML.Form.input_value(form, :type) do
      :company -> true
      "company" -> true
      _ -> false
    end
  end

  defp assign_form(%{assigns: %{customer: customer}} = socket) do
    member = socket.assigns.current_member

    form =
      if customer do
        AshPhoenix.Form.for_update(customer, :update,
          as: "customer",
          actor: member,
          tenant: member.organisation_id
        )
      else
        AshPhoenix.Form.for_create(OpenSauce.CRM.Customer, :create,
          as: "customer",
          actor: member,
          tenant: member.organisation_id
        )
      end

    assign(socket, form: to_form(form))
  end
end
