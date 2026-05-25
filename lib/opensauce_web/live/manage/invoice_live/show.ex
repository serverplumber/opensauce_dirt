defmodule OpenSauceWeb.InvoiceLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import Ash.Query

  alias OpenSauce.CRM
  alias OpenSauce.Orders
  alias OpenSauceWeb.Components.Page
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <Page.page>
      <.header>
        Invoice {@invoice.reference}
        <:subtitle>
          <span class={["px-2 py-0.5 rounded text-xs font-medium", status_class(@invoice.status)]}>
            {@invoice.status}
          </span>
        </:subtitle>
        <:actions>
          <.link patch={~p"/manage/invoices/#{@invoice.id}/edit"}>
            <.button variant={:outline}>Edit</.button>
          </.link>
          <.button
            :if={@invoice.status == :draft}
            phx-click="mark_sent"
            variant={:outline}
          >
            Mark Sent
          </.button>
          <.button
            :if={@invoice.status in [:draft, :sent]}
            phx-click="mark_paid"
            variant={:primary}
          >
            Mark Paid
          </.button>
        </:actions>
      </.header>

      <Page.section>
        <Page.two_column>
          <:left>
            <Page.surface>
              <:header>
                <h3 class="text-sm font-semibold text-stone-900">Details</h3>
              </:header>
              <dl class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <dt class="text-stone-500">Customer</dt>
                  <dd class="font-medium">
                    <.link :if={@invoice.customer} navigate={~p"/manage/customers/#{@invoice.customer.reference}"} class="text-primary-600 hover:underline">
                      {@invoice.customer.first_name} {@invoice.customer.last_name}
                    </.link>
                    <span :if={!@invoice.customer}>—</span>
                  </dd>
                </div>
                <div :if={@invoice.engagement} class="flex justify-between">
                  <dt class="text-stone-500">Engagement</dt>
                  <dd class="font-medium text-stone-700">{@invoice.engagement.scope_description || Atom.to_string(@invoice.engagement.status)}</dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-stone-500">Issued</dt>
                  <dd class="font-medium">{@invoice.issued_on}</dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-stone-500">Due</dt>
                  <dd class="font-medium">{@invoice.due_on || "—"}</dd>
                </div>
                <div class="flex justify-between border-t border-stone-100 pt-3">
                  <dt class="font-semibold text-stone-700">Amount</dt>
                  <dd class="text-lg font-bold text-stone-900">
                    {format_money(@organisation.currency, @invoice.amount)}
                  </dd>
                </div>
                <div :if={@invoice.notes} class="pt-2">
                  <dt class="mb-1 text-stone-500">Notes</dt>
                  <dd class="text-stone-700">{@invoice.notes}</dd>
                </div>
              </dl>
            </Page.surface>
          </:left>
          <:right>
            <Page.surface>
              <:header>
                <h3 class="text-sm font-semibold text-stone-900">Jobs</h3>
              </:header>
              <div :if={Enum.empty?(@jobs)} class="py-4 text-sm text-stone-500">
                No jobs linked to this invoice.
              </div>
              <.table :if={!Enum.empty?(@jobs)} id="invoice-jobs" rows={@jobs}>
                <:col :let={job} label="Date">
                  {job.scheduled_for}
                </:col>
                <:col :let={job} label="Type">
                  {(job.service_category || job.type) |> Atom.to_string() |> String.replace("_", " ")}
                </:col>
                <:col :let={job} label="Status">
                  {job.status}
                </:col>
                <:col :let={job} label="Cost">
                  {format_money(@organisation.currency, job.materials_cost)}
                </:col>
              </.table>
            </Page.surface>
          </:right>
        </Page.two_column>
      </Page.section>

      <.modal
        :if={@live_action == :edit}
        id="invoice-edit-modal"
        title="Edit Invoice"
        show
        on_cancel={JS.patch(~p"/manage/invoices/#{@invoice.id}")}
      >
        <.live_component
          module={OpenSauceWeb.InvoiceLive.FormComponent}
          id={@invoice.id}
          current_member={@current_member}
          invoice={@invoice}
          patch={~p"/manage/invoices/#{@invoice.id}"}
        />
      </.modal>
    </Page.page>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    member = socket.assigns.current_member
    invoice = load_invoice(id, member)

    jobs =
      Orders.Job
      |> filter(invoice_id == ^id)
      |> Ash.Query.load(:materials_cost)
      |> Ash.read!(actor: member, tenant: member.organisation_id)

    socket =
      socket
      |> assign(:invoice, invoice)
      |> assign(:jobs, jobs)
      |> assign(:page_title, "Invoice #{invoice.reference}")

    {:noreply, Navigation.assign(socket, :invoices, [Navigation.root(:invoices), Navigation.resource(:invoice, invoice)])}
  end

  @impl true
  def handle_event("mark_paid", _params, socket) do
    member = socket.assigns.current_member
    {:ok, invoice} = CRM.mark_invoice_paid(socket.assigns.invoice, actor: member, tenant: member.organisation_id)
    {:noreply, assign(socket, :invoice, load_invoice(invoice.id, member))}
  end

  @impl true
  def handle_event("mark_sent", _params, socket) do
    member = socket.assigns.current_member
    {:ok, invoice} = CRM.mark_invoice_sent(socket.assigns.invoice, actor: member, tenant: member.organisation_id)
    {:noreply, assign(socket, :invoice, load_invoice(invoice.id, member))}
  end

  @impl true
  def handle_info({OpenSauceWeb.InvoiceLive.FormComponent, {:saved, invoice}}, socket) do
    member = socket.assigns.current_member
    {:noreply, assign(socket, :invoice, load_invoice(invoice.id, member))}
  end

  defp load_invoice(id, member) do
    CRM.get_invoice_by_id!(id,
      actor: member,
      tenant: member.organisation_id,
      load: [:customer, :engagement]
    )
  end

  defp status_class(:draft), do: "bg-stone-100 text-stone-600"
  defp status_class(:sent), do: "bg-blue-100 text-blue-700"
  defp status_class(:paid), do: "bg-emerald-100 text-emerald-700"
  defp status_class(:void), do: "bg-red-100 text-red-600"
  defp status_class(_), do: "bg-stone-100 text-stone-600"
end
