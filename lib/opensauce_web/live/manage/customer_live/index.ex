defmodule OpenSauceWeb.CustomerLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto space-y-4">
      <div class="flex items-center justify-between pt-1">
        <h1 class="text-lg font-semibold text-stone-900">Customers</h1>
        <.link navigate={~p"/manage/customers/new"} class="text-sm font-medium text-amber-600 hover:text-amber-700">
          + New
        </.link>
      </div>

      <div id="customers" phx-update="stream" class="space-y-2">
        <div :for={{dom_id, customer} <- @streams.customers} id={dom_id}>
          <.link
            navigate={~p"/manage/customers/#{customer.reference}"}
            class="flex items-center gap-3 bg-white rounded-xl border border-stone-200 px-4 py-3 hover:bg-stone-50 active:bg-stone-100"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-stone-900 truncate">{customer.full_name}</p>
              <p :if={customer.company_name_nickname} class="text-xs text-stone-500 truncate">
                {customer.company_name_nickname}
              </p>
              <p class="text-xs text-stone-400 mt-0.5">
                {garden_count_label(customer.garden_addresses)}
              </p>
            </div>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-stone-300 shrink-0" />
          </.link>
        </div>
      </div>

      <p :if={@customer_count == 0} class="text-sm text-stone-400 text-center py-8">
        No customers yet
      </p>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    customers =
      OpenSauce.CRM.list_customers!(
        actor: socket.assigns.current_member,
        tenant: socket.assigns.current_member.organisation_id,
        load: [:full_name, :garden_addresses]
      )

    {:ok,
     socket
     |> stream(:customers, customers)
     |> assign(:customer_count, length(customers))
     |> assign_new(:current_member, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    {:noreply, Navigation.assign(socket, :customers, customer_index_trail(socket.assigns))}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Customers")
  end

  defp customer_index_trail(_), do: [Navigation.root(:customers)]

  defp garden_count_label([]), do: "No gardens"
  defp garden_count_label([_]), do: "1 garden"
  defp garden_count_label(gardens), do: "#{length(gardens)} gardens"
end
