defmodule OpenSauceWeb.InvoiceLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.Components.Page
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <Page.page>
      <.header>
        Invoices
        <:subtitle>Track billing across jobs and engagements.</:subtitle>
        <:actions>
          <.link patch={~p"/manage/invoices/new"}>
            <.button variant={:primary}>New Invoice</.button>
          </.link>
        </:actions>
      </.header>

      <Page.section>
        <Page.surface>
          <.table
            id="invoices"
            rows={@invoices}
            row_click={fn invoice -> JS.navigate(~p"/manage/invoices/#{invoice.id}") end}
          >
            <:empty>
              <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-10 text-center text-sm text-stone-500">
                No invoices yet.
              </div>
            </:empty>
            <:col :let={invoice} label="Reference">
              <.kbd>{invoice.reference}</.kbd>
            </:col>
            <:col :let={invoice} label="Customer">
              {invoice.customer && "#{invoice.customer.first_name} #{invoice.customer.last_name}"}
            </:col>
            <:col :let={invoice} label="Issued">
              {invoice.issued_on}
            </:col>
            <:col :let={invoice} label="Due">
              {invoice.due_on || "—"}
            </:col>
            <:col :let={invoice} label="Amount">
              {format_money(@settings.currency, invoice.amount)}
            </:col>
            <:col :let={invoice} label="Status">
              <span class={["px-2 py-0.5 rounded text-xs font-medium", status_class(invoice.status)]}>
                {invoice.status}
              </span>
            </:col>
            <:action :let={invoice}>
              <.link navigate={~p"/manage/invoices/#{invoice.id}"} class="text-sm text-stone-500 hover:text-stone-700">
                View
              </.link>
            </:action>
          </.table>
        </Page.surface>
      </Page.section>

      <.modal
        :if={@live_action == :new}
        id="invoice-modal"
        title="New Invoice"
        show
        on_cancel={JS.patch(~p"/manage/invoices")}
      >
        <.live_component
          module={OpenSauceWeb.InvoiceLive.FormComponent}
          id={:new}
          current_member={@current_member}
          settings={@settings}
          invoice={nil}
          patch={~p"/manage/invoices"}
        />
      </.modal>
    </Page.page>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :invoices, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> load_invoices()

    {:noreply, Navigation.assign(socket, :invoices, [Navigation.root(:invoices)])}
  end

  @impl true
  def handle_info({OpenSauceWeb.InvoiceLive.FormComponent, {:saved, _invoice}}, socket) do
    {:noreply, load_invoices(socket)}
  end

  defp load_invoices(socket) do
    member = socket.assigns.current_member

    invoices =
      CRM.list_invoices!(
        actor: member,
        tenant: member.organisation_id,
        load: [:customer]
      )

    assign(socket, :invoices, invoices)
  end

  defp page_title(:new), do: "New Invoice"
  defp page_title(_), do: "Invoices"

  defp status_class(:draft), do: "bg-stone-100 text-stone-600"
  defp status_class(:sent), do: "bg-blue-100 text-blue-700"
  defp status_class(:paid), do: "bg-emerald-100 text-emerald-700"
  defp status_class(:void), do: "bg-red-100 text-red-600"
  defp status_class(_), do: "bg-stone-100 text-stone-600"
end
