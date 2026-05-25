defmodule OpenSauceWeb.EngagementLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="engagement-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-4">
          <%!-- Customer selector — only shown when not pre-set from a customer page --%>
          <.input
            :if={@standalone}
            name="engagement[customer_id]"
            id="engagement_customer_id"
            type="select"
            label="Customer"
            options={Enum.map(@customers, &{customer_label(&1), &1.id})}
            value={@customer_id}
            prompt="Select a customer"
          />

          <.input
            field={@form[:garden_id]}
            type="select"
            label="Garden"
            options={[{"— none —", ""}] ++ Enum.map(@gardens, &{garden_label(&1), &1.id})}
          />

          <.input
            field={@form[:scope_description]}
            type="textarea"
            label="Scope"
            rows="4"
          />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:install_price]}
              type="number"
              label="Install price"
              step="0.01"
              min="0"
            />
            <.input
              field={@form[:maintenance_price_annual]}
              type="number"
              label="Annual maintenance"
              step="0.01"
              min="0"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:term_start]} type="date" label="Term start" />
            <.input field={@form[:term_end]} type="date" label="Term end" />
          </div>

          <.input
            field={@form[:status]}
            type="select"
            label="Status"
            options={[
              {"Draft", :draft},
              {"Proposed", :proposed},
              {"Signed", :signed},
              {"In progress", :in_progress},
              {"Completed", :completed},
              {"Cancelled", :cancelled}
            ]}
          />

          <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Engagement</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{engagement: engagement, customer: customer} = assigns, socket) do
    member = assigns.current_member
    standalone = is_nil(customer)

    {customer_id, gardens, customers} =
      if standalone do
        all = load_customers(member)
        {"", [], all}
      else
        {customer.id, customer.garden_addresses, []}
      end

    form =
      if engagement do
        AshPhoenix.Form.for_update(engagement, :update,
          as: "engagement",
          actor: member,
          tenant: member.organisation_id
        )
      else
        AshPhoenix.Form.for_create(CRM.Engagement, :create,
          as: "engagement",
          actor: member,
          tenant: member.organisation_id
        )
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:standalone, standalone)
     |> assign(:customer_id, customer_id)
     |> assign(:customers, customers)
     |> assign(:gardens, gardens)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"engagement" => params}, socket) do
    {customer_id, gardens} =
      if socket.assigns.standalone do
        new_customer_id = params["customer_id"] || ""

        if new_customer_id != socket.assigns.customer_id and new_customer_id != "" do
          gardens = load_gardens(new_customer_id, socket.assigns.current_member)
          {new_customer_id, gardens}
        else
          {new_customer_id, socket.assigns.gardens}
        end
      else
        {socket.assigns.customer_id, socket.assigns.gardens}
      end

    params = Map.put(params, "customer_id", customer_id)
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:customer_id, customer_id)
     |> assign(:gardens, gardens)}
  end

  def handle_event("save", %{"engagement" => params}, socket) do
    customer_id =
      if socket.assigns.standalone,
        do: params["customer_id"] || socket.assigns.customer_id,
        else: socket.assigns.customer_id

    params = Map.put(params, "customer_id", customer_id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, engagement} ->
        notify_parent({:saved, engagement})

        {:noreply,
         socket
         |> put_flash(:info, "Engagement saved.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp load_customers(member) do
    CRM.list_customers!(actor: member, tenant: member.organisation_id)
  rescue
    _ -> []
  end

  defp load_gardens(customer_id, member) do
    case CRM.get_customer_by_id(customer_id,
           actor: member,
           tenant: member.organisation_id,
           load: [garden_addresses: [:short_address]]
         ) do
      {:ok, customer} -> customer.garden_addresses
      _ -> []
    end
  end

  defp customer_label(c) do
    if c.company_name_nickname,
      do: "#{c.company_name_nickname} (#{c.first_name} #{c.last_name})",
      else: "#{c.first_name} #{c.last_name}"
  end

  defp garden_label(addr) do
    name = addr.name || "Garden"
    short = addr.short_address
    if short, do: "#{name} — #{short}", else: name
  end
end
