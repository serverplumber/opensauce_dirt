defmodule OpenSauceWeb.CustomerLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.Navigation

  @empty_draft %{
    "name" => "",
    "street" => "",
    "city" => "",
    "province" => "",
    "zip" => "",
    "notes" => "",
    "is_billing" => "false"
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto space-y-4 pb-36">
      <%!-- Back + edit row --%>
      <div class="flex items-center justify-between pt-1">
        <.link navigate={~p"/manage/customers"} class="text-stone-500 hover:text-stone-700 p-1 -ml-1">
          <.icon name="hero-arrow-left" class="h-5 w-5" />
        </.link>
        <.link
          patch={~p"/manage/customers/#{@customer.reference}/edit"}
          class="text-sm font-medium text-stone-500 hover:text-stone-700"
        >
          Edit
        </.link>
      </div>

      <%!-- Identity card --%>
      <div class="bg-white rounded-xl border border-stone-200 px-4 py-4 space-y-4">
        <div>
          <p class="text-xl font-bold text-stone-900">{@customer.full_name}</p>
          <p :if={@customer.type == :company and @customer.company_name_nickname} class="text-sm text-stone-500 mt-0.5">
            {@customer.company_name_nickname}
          </p>
        </div>
        <div class="flex gap-3">
          <a
            :if={@customer.phone}
            href={"tel:#{@customer.phone}"}
            class="flex-1 flex items-center justify-center gap-2 rounded-xl border border-stone-200 py-2.5 text-sm font-medium text-stone-700 hover:bg-stone-50 active:bg-stone-100"
          >
            <.icon name="hero-phone" class="h-4 w-4 text-stone-500" />
            Call
          </a>
          <a
            :if={@customer.email}
            href={"mailto:#{@customer.email}"}
            class="flex-1 flex items-center justify-center gap-2 rounded-xl border border-stone-200 py-2.5 text-sm font-medium text-stone-700 hover:bg-stone-50 active:bg-stone-100"
          >
            <.icon name="hero-envelope" class="h-4 w-4 text-stone-500" />
            Email
          </a>
          <div
            :if={is_nil(@customer.phone) and is_nil(@customer.email)}
            class="flex-1 text-sm text-stone-400 text-center py-2.5"
          >
            No contact info
          </div>
        </div>
      </div>

      <%!-- KPI row --%>
      <div class="grid grid-cols-3 gap-3">
        <div class="bg-white rounded-xl border border-stone-200 p-3 text-center">
          <p class="text-2xl font-bold text-stone-900">{length(@customer.garden_addresses)}</p>
          <p class="text-xs text-stone-500 mt-0.5">Gardens</p>
        </div>
        <div class="bg-white rounded-xl border border-stone-200 p-3 text-center">
          <p class="text-2xl font-bold text-stone-900">
            {length(@customer.engagements)}/{Enum.sum(Map.values(@open_jobs_by_garden))}
          </p>
          <p class="text-xs text-stone-500 mt-0.5">Eng · Jobs</p>
        </div>
        <div class="bg-white rounded-xl border border-stone-200 p-3 text-center">
          <p class="text-sm font-bold text-stone-900 leading-tight">
            {format_due_billed(@customer.invoices)}
          </p>
          <p class="text-xs text-stone-500 mt-0.5">Due / Billed</p>
        </div>
      </div>

      <%!-- Gardens --%>
      <div class="bg-white rounded-xl border border-stone-200">
        <div class="px-4 py-3 border-b border-stone-100 flex items-center justify-between">
          <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wider">Gardens</h2>
          <button
            type="button"
            phx-click="open_garden_sheet"
            class="text-amber-600 hover:text-amber-700 p-1 -mr-1"
            aria-label="Add garden"
          >
            <.icon name="hero-plus" class="h-4 w-4" />
          </button>
        </div>
        <div
          :for={addr <- @customer.garden_addresses}
          class="px-4 py-3 border-b border-stone-100 last:border-0"
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2 flex-1 min-w-0">
              <.icon
                :if={addr.is_billing}
                name="hero-document-currency-dollar"
                class="h-4 w-4 text-amber-500 shrink-0"
              />
              <div class="min-w-0">
                <p class="text-sm font-medium text-stone-900 truncate">
                  {addr.name || "Unnamed garden"}
                </p>
                <p :if={addr.full_address} class="text-xs text-stone-500 mt-0.5 truncate">
                  {addr.full_address}
                </p>
                <p :if={addr.notes} class="text-xs text-stone-400 mt-0.5 italic truncate">
                  {addr.notes}
                </p>
              </div>
            </div>
            <span
              :if={Map.get(@open_jobs_by_garden, addr.id, 0) > 0}
              class="shrink-0 text-xs font-semibold text-stone-600 bg-stone-100 rounded-full px-2 py-0.5"
            >
              {Map.get(@open_jobs_by_garden, addr.id)} open
            </span>
          </div>
        </div>
        <div
          :if={Enum.empty?(@customer.garden_addresses)}
          class="px-4 py-4 text-sm text-stone-400 text-center"
        >
          No gardens — tap + to add one
        </div>
      </div>

      <%!-- Engagements --%>
      <div class="bg-white rounded-xl border border-stone-200">
        <div class="px-4 py-3 border-b border-stone-100 flex items-center justify-between">
          <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wider">Engagements</h2>
          <.link
            patch={~p"/manage/customers/#{@customer.reference}/engagements/new"}
            class="text-amber-600 hover:text-amber-700 p-1 -mr-1"
            aria-label="New engagement"
          >
            <.icon name="hero-plus" class="h-4 w-4" />
          </.link>
        </div>
        <div
          :for={e <- @customer.engagements}
          class="px-4 py-3 border-b border-stone-100 last:border-0"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-stone-900 truncate">
                {if e.garden, do: e.garden.name || "Garden", else: "—"}
              </p>
              <p
                :if={format_term(e.term_start, e.term_end) != "—"}
                class="text-xs text-stone-500 mt-0.5"
              >
                {format_term(e.term_start, e.term_end)}
              </p>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <.badge text={e.status} colors={[{e.status, engagement_status_class(e.status)}]} />
              <button
                type="button"
                phx-click="open_schedule_job"
                phx-value-id={e.id}
                class="text-stone-400 hover:text-stone-600 p-1"
                title="Schedule job"
              >
                <.icon name="hero-calendar" class="h-4 w-4" />
              </button>
              <.link
                patch={~p"/manage/customers/#{@customer.reference}/engagements/#{e.id}/edit"}
                class="text-stone-400 hover:text-stone-600 p-1"
              >
                <.icon name="hero-pencil-square" class="h-4 w-4" />
              </.link>
            </div>
          </div>
        </div>
        <div
          :if={Enum.empty?(@customer.engagements)}
          class="px-4 py-4 text-sm text-stone-400 text-center"
        >
          No engagements yet
        </div>
      </div>
    </div>

    <%!-- Sticky bottom CTA (above bottom nav) --%>
    <div class="fixed bottom-16 left-0 right-0 px-4 pb-2 bg-gradient-to-t from-stone-50 via-stone-50/95 to-transparent pt-4 pointer-events-none">
      <.link
        navigate={~p"/manage/jobs/new"}
        class="pointer-events-auto block w-full rounded-xl bg-amber-500 py-3 text-center text-sm font-semibold text-white shadow-sm hover:bg-amber-600 active:bg-amber-700"
      >
        New Job
      </.link>
    </div>

    <%!-- Add garden slide-up sheet --%>
    <div
      :if={@show_garden_sheet}
      id="garden-sheet"
      class="fixed inset-0 z-50"
      role="dialog"
      aria-modal="true"
      aria-label="Add garden"
    >
      <div class="absolute inset-0 bg-black/40" phx-click="close_garden_sheet"></div>
      <div class="absolute bottom-0 left-0 right-0 bg-white rounded-t-2xl shadow-2xl max-h-[85dvh] flex flex-col">
        <div class="flex items-center justify-between px-4 py-3 border-b border-stone-100 shrink-0">
          <h3 class="text-base font-semibold text-stone-900">Add garden</h3>
          <button
            type="button"
            phx-click="close_garden_sheet"
            class="text-stone-400 hover:text-stone-600 p-1 -mr-1"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>
        <.form
          for={:garden}
          id="garden-draft-form"
          phx-submit="add_garden"
          class="flex-1 overflow-y-auto p-4 space-y-4"
        >
          <.input name="garden[name]" id="draft-name" value={@draft["name"]} label="Garden name" />
          <.input name="garden[street]" id="draft-street" value={@draft["street"]} label="Street" />
          <div class="grid grid-cols-2 gap-3">
            <.input name="garden[city]" id="draft-city" value={@draft["city"]} label="City" />
            <.input name="garden[province]" id="draft-province" value={@draft["province"]} label="Province" />
          </div>
          <.input name="garden[zip]" id="draft-zip" value={@draft["zip"]} label="Postal code" />
          <.input
            name="garden[notes]"
            id="draft-notes"
            value={@draft["notes"]}
            label="Notes"
          />
          <label class="flex items-center justify-between rounded-xl border border-stone-200 px-4 py-3 cursor-pointer">
            <div>
              <p class="text-sm font-medium text-stone-900">Billing address</p>
              <p class="text-xs text-stone-500 mt-0.5">Use this garden for invoices</p>
            </div>
            <button
              type="button"
              phx-click="toggle_draft_billing"
              class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors " <> if(@draft["is_billing"] == "true", do: "bg-amber-500", else: "bg-stone-200")}
              role="switch"
              aria-checked={@draft["is_billing"] == "true"}
            >
              <span class={"inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform " <> if(@draft["is_billing"] == "true", do: "translate-x-6", else: "translate-x-1")} />
            </button>
            <input type="hidden" name="garden[is_billing]" value={@draft["is_billing"]} />
          </label>
          <div class="flex gap-3 pt-2">
            <button
              type="button"
              phx-click="close_garden_sheet"
              class="flex-1 rounded-xl border border-stone-200 py-3 text-sm font-medium text-stone-700 hover:bg-stone-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="flex-1 rounded-xl bg-amber-500 py-3 text-sm font-medium text-white hover:bg-amber-600"
            >
              Add garden
            </button>
          </div>
        </.form>
      </div>
    </div>

    <%!-- Edit customer modal --%>
    <.modal
      :if={@live_action == :edit}
      id="customer-modal"
      title="Edit Customer"
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}")}
    >
      <.live_component
        module={OpenSauceWeb.CustomerLive.FormComponent}
        id={@customer.id}
        current_member={@current_member}
        action={@live_action}
        customer={@customer}
        patch={~p"/manage/customers/#{@customer.reference}"}
      />
    </.modal>

    <%!-- New engagement modal --%>
    <.modal
      :if={@live_action == :new_engagement}
      id="engagement-new-modal"
      title="New Engagement"
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.FormComponent}
        id="engagement-new"
        current_member={@current_member}
        engagement={nil}
        customer={@customer}
        patch={~p"/manage/customers/#{@customer.reference}"}
      />
    </.modal>

    <%!-- Edit engagement modal --%>
    <.modal
      :if={@live_action == :edit_engagement}
      id="engagement-edit-modal"
      title="Edit Engagement"
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.FormComponent}
        id={"engagement-#{@engagement && @engagement.id}"}
        current_member={@current_member}
        engagement={@engagement}
        customer={@customer}
        patch={~p"/manage/customers/#{@customer.reference}"}
      />
    </.modal>

    <%!-- Engagement materials modal --%>
    <.modal
      :if={@live_action == :engagement_materials}
      id="engagement-materials-modal"
      title="Materials"
      max_width="max-w-3xl"
      show
      on_cancel={JS.patch(~p"/manage/customers/#{@customer.reference}")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.MaterialsComponent}
        id={"materials-#{@engagement_id}"}
        engagement_id={@engagement_id}
        current_member={@current_member}
        currency={@organisation.currency}
      />
    </.modal>

    <%!-- Schedule job modal --%>
    <.modal
      :if={@schedule_job_engagement != nil}
      id="schedule-job-modal"
      title={"New job — #{schedule_job_title(@schedule_job_engagement)}"}
      max_width="max-w-xl"
      show
      on_cancel={JS.push("close_schedule_job")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.ScheduleJobComponent}
        id={"schedule-job-#{@schedule_job_engagement.id}"}
        engagement={@schedule_job_engagement}
        current_member={@current_member}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:engagement, nil)
     |> assign(:engagement_id, nil)
     |> assign(:schedule_job_engagement, nil)
     |> assign(:show_garden_sheet, false)
     |> assign(:draft, @empty_draft)
     |> assign(:open_jobs_by_garden, %{})}
  end

  @impl true
  def handle_params(%{"reference" => reference} = params, _, socket) do
    customer = load_customer(reference, socket)
    live_action = socket.assigns.live_action

    engagement =
      if live_action == :edit_engagement do
        Enum.find(customer.engagements, &(&1.id == params["engagement_id"]))
      end

    socket =
      socket
      |> assign(:page_title, short_name(customer))
      |> assign(:customer, customer)
      |> assign(:engagement, engagement)
      |> assign(:engagement_id, params["engagement_id"])
      |> assign(:open_jobs_by_garden, open_jobs_by_garden(customer, socket))

    {:noreply, Navigation.assign(socket, :customers, customer_trail(customer))}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case CRM.destroy_customer(socket.assigns.customer,
           actor: socket.assigns.current_member,
           tenant: socket.assigns.current_member.organisation_id
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer deleted.")
         |> push_navigate(to: ~p"/manage/customers")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete customer.")}
    end
  end

  @impl true
  def handle_event("open_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: true, draft: @empty_draft)}
  end

  def handle_event("close_garden_sheet", _params, socket) do
    {:noreply, assign(socket, show_garden_sheet: false)}
  end

  def handle_event("toggle_draft_billing", _params, socket) do
    new_val = if socket.assigns.draft["is_billing"] == "true", do: "false", else: "true"
    {:noreply, assign(socket, draft: Map.put(socket.assigns.draft, "is_billing", new_val))}
  end

  def handle_event("add_garden", %{"garden" => params}, socket) do
    member = socket.assigns.current_member
    customer = socket.assigns.customer
    is_billing_new = params["is_billing"] == "true"

    existing =
      Enum.map(customer.garden_addresses, fn addr ->
        %{
          "id" => addr.id,
          "name" => addr.name || "",
          "street" => addr.street || "",
          "city" => addr.city || "",
          "province" => addr.province || "",
          "zip" => addr.zip || "",
          "notes" => addr.notes,
          "is_garden" => "true",
          "is_billing" => if(is_billing_new, do: "false", else: to_string(addr.is_billing)),
          "is_indoor" => to_string(addr.is_indoor)
        }
      end)

    all_gardens = existing ++ [Map.put(params, "is_garden", "true")]

    result =
      customer
      |> Ash.Changeset.for_update(:update, %{garden_addresses: all_gardens},
        actor: member,
        tenant: member.organisation_id
      )
      |> Ash.update()

    case result do
      {:ok, _} ->
        updated_customer = load_customer(customer.reference, socket)

        {:noreply,
         socket
         |> assign(:customer, updated_customer)
         |> assign(:open_jobs_by_garden, open_jobs_by_garden(updated_customer, socket))
         |> assign(:show_garden_sheet, false)
         |> assign(:draft, @empty_draft)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not add garden.")
         |> assign(:show_garden_sheet, false)}
    end
  end

  @impl true
  def handle_event("open_schedule_job", %{"id" => id}, socket) do
    engagement = Enum.find(socket.assigns.customer.engagements, &(&1.id == id))
    {:noreply, assign(socket, :schedule_job_engagement, engagement)}
  end

  def handle_event("close_schedule_job", _params, socket) do
    {:noreply, assign(socket, :schedule_job_engagement, nil)}
  end

  @impl true
  def handle_info({OpenSauceWeb.CustomerLive.FormComponent, {:saved, customer}}, socket) do
    {:noreply, assign(socket, :customer, load_customer(customer.reference, socket))}
  end

  def handle_info({OpenSauceWeb.EngagementLive.FormComponent, {:saved, _engagement}}, socket) do
    {:noreply, assign(socket, :customer, load_customer(socket.assigns.customer.reference, socket))}
  end

  def handle_info(
        {OpenSauceWeb.EngagementLive.ScheduleJobComponent, {:job_created, _job, count}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:customer, load_customer(socket.assigns.customer.reference, socket))
     |> assign(:schedule_job_engagement, nil)
     |> put_flash(:info, "Job scheduled with #{count} plant#{if count == 1, do: "", else: "s"}.")}
  end

  defp load_customer(reference, socket) do
    CRM.get_customer_by_reference!(
      reference,
      actor: socket.assigns.current_member,
      tenant: socket.assigns.current_member.organisation_id,
      load: [
        :full_name,
        garden_addresses: [:name, :full_address, :is_billing, :notes, :is_indoor],
        invoices: [:amount, :status],
        engagements: [:total_quoted_value, :materials, garden: [:name]]
      ]
    )
  end

  defp open_jobs_by_garden(customer, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    customer.garden_addresses
    |> Enum.map(fn addr ->
      count =
        case OpenSauce.Orders.list_jobs_at_garden(addr.id, opts) do
          {:ok, jobs} -> length(jobs)
          _ -> 0
        end

      {addr.id, count}
    end)
    |> Enum.reject(fn {_, count} -> count == 0 end)
    |> Map.new()
  end

  defp short_name(customer) do
    customer.company_name_nickname || customer.first_name
  end

  defp customer_trail(customer),
    do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]

  defp schedule_job_title(engagement) do
    if engagement.garden, do: engagement.garden.name || "garden", else: "engagement"
  end

  defp format_due_billed(invoices) do
    zero = Decimal.new(0)
    billed = invoices |> Enum.map(& &1.amount) |> Enum.reject(&is_nil/1) |> Enum.reduce(zero, &Decimal.add/2)
    due = invoices |> Enum.filter(&(&1.status == :sent)) |> Enum.map(& &1.amount) |> Enum.reject(&is_nil/1) |> Enum.reduce(zero, &Decimal.add/2)
    "#{Decimal.to_string(due, :normal)} / #{Decimal.to_string(billed, :normal)}"
  end

  defp format_term(nil, nil), do: "—"
  defp format_term(start, nil), do: "From #{Date.to_iso8601(start)}"
  defp format_term(nil, end_date), do: "Until #{Date.to_iso8601(end_date)}"
  defp format_term(start, end_date), do: "#{Date.to_iso8601(start)} → #{Date.to_iso8601(end_date)}"

  defp engagement_status_class(:draft), do: "text-gray-600 bg-gray-100"
  defp engagement_status_class(:proposed), do: "text-amber-700 bg-amber-100"
  defp engagement_status_class(:signed), do: "text-blue-700 bg-blue-100"
  defp engagement_status_class(:in_progress), do: "text-green-700 bg-green-100"
  defp engagement_status_class(:completed), do: "text-emerald-700 bg-emerald-100"
  defp engagement_status_class(:cancelled), do: "text-red-700 bg-red-100"
  defp engagement_status_class(_), do: "text-gray-600 bg-gray-100"
end
