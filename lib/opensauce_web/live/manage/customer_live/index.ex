defmodule OpenSauceWeb.CustomerLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Customers
      <:subtitle>Manage your customer records</:subtitle>
      <:actions>
        <.link patch={~p"/manage/customers/new"}>
          <.button variant={:primary}>New Customer</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="customers"
      rows={@streams.customers}
      row_click={fn {_id, customer} -> JS.navigate(~p"/manage/customers/#{customer.reference}") end}
    >
      <:empty>
        <div class="block py-4 pr-6">
          <span class={["relative"]}>
            No customers found
          </span>
        </div>
      </:empty>
      <:col :let={{_id, customer}} label="Name">{customer.company_name_nickname}</:col>
      <:col :let={{_id, customer}} label="Email">{customer.email}</:col>
      <:col :let={{_id, customer}} label="Phone">{customer.phone}</:col>
      <:col :let={{_id, customer}} label="Gardens">
        <div :for={addr <- customer.garden_addresses} class="text-sm leading-snug">
          <span class="font-medium">{addr.name}</span>
          <span :if={addr.short_address} class="text-stone-500">: {addr.short_address}</span>
        </div>
      </:col>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="customer-modal"
      title={@page_title}
      description="Use this form to manage customer records in your database."
      show
      on_cancel={JS.patch(~p"/manage/customers")}
    >
      <.live_component
        module={OpenSauceWeb.CustomerLive.FormComponent}
        id={(@customer && @customer.id) || :new}
        current_member={@current_member}
        title={@page_title}
        action={@live_action}
        customer={@customer}
        settings={@settings}
        patch={~p"/manage/customers"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(
       :customers,
       OpenSauce.CRM.list_customers!(
         actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id,
         load: [:full_name, garden_addresses: [:short_address]]
       )
     )
     |> assign_new(:current_member, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    {:noreply, Navigation.assign(socket, :customers, customer_index_trail(socket.assigns))}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(
      :customer,
      OpenSauce.CRM.get_customer_by_id!(id,
        actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id,
        load: [:billing_address, :garden_addresses]
      )
    )
  end

  defp apply_action(socket, :edit, %{"reference" => reference}) do
    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(
      :customer,
      OpenSauce.CRM.get_customer_by_reference!(reference,
        actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id,
        load: [:billing_address, :garden_addresses]
      )
    )
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Customer")
    |> assign(:customer, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Customers")
    |> assign(:customer, nil)
  end

  defp customer_index_trail(%{live_action: :new}),
    do: [Navigation.root(:customers), Navigation.page(:customers, :new_customer)]

  defp customer_index_trail(%{live_action: :edit, customer: %{} = customer}),
    do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]

  defp customer_index_trail(_), do: [Navigation.root(:customers)]

  @impl true
  def handle_info({OpenSauceWeb.CustomerLive.FormComponent, {:saved, customer}}, socket) do
    {:noreply, stream_insert(socket, :customers, customer)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> OpenSauce.CRM.get_customer_by_id!(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id)
         |> OpenSauce.CRM.destroy_customer(actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer deleted successfully")
         |> stream_delete(:customers, %{id: id})}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete customer.")}
    end
  end
end
