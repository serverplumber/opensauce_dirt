defmodule OpenSauceWeb.InvoiceLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  import Ash.Query

  alias OpenSauce.CRM
  alias OpenSauce.Orders
  alias Decimal, as: D

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:customer_id, fn -> nil end)
      |> assign_new(:selected_jobs, fn -> [] end)
      |> assign_new(:hidden_job_ids, fn -> MapSet.new() end)
      |> assign_new(:selected_engagement, fn -> nil end)
      |> assign_new(:engagement_hidden, fn -> false end)
      |> assign_new(:engagement_amount, fn -> "" end)
      |> assign_new(:custom_line_items, fn -> [] end)
      |> assign_new(:params, fn ->
        %{
          "reference" => "",
          "issued_on" => Date.to_iso8601(Date.utc_today()),
          "due_on" => "",
          "notes" => "",
          "status" => "draft"
        }
      end)
      |> load_customers()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <form id="invoice-form" phx-change="validate" phx-submit="save" phx-target={@myself} class="space-y-5">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-medium text-stone-700 mb-1">Reference</label>
            <input type="text" name="invoice[reference]" value={@params["reference"]}
              class="block w-full rounded-md border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              required />
          </div>
          <div>
            <label class="block text-xs font-medium text-stone-700 mb-1">Customer</label>
            <select name="invoice[customer_id]"
              class="block w-full rounded-md border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500">
              <option value="">Select customer…</option>
              <option :for={{label, id} <- @customers} value={id} selected={id == @customer_id}>
                {label}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-stone-700 mb-1">Issued</label>
            <input type="date" name="invoice[issued_on]" value={@params["issued_on"]}
              class="block w-full rounded-md border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              required />
          </div>
          <div>
            <label class="block text-xs font-medium text-stone-700 mb-1">Due</label>
            <input type="date" name="invoice[due_on]" value={@params["due_on"]}
              class="block w-full rounded-md border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500" />
          </div>
        </div>

        <div :if={@customer_id && @customer_id != ""}>
          <div class="mb-2 flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-wide text-stone-500">Jobs</span>
            <span class="text-xs text-stone-400">{length(@selected_jobs)} loaded</span>
          </div>
          <div class="space-y-1">
            <div
              :for={job <- @selected_jobs}
              class={[
                "flex items-center gap-2 rounded-md border px-3 py-2 transition",
                if(MapSet.member?(@hidden_job_ids, job.id),
                  do: "border-stone-100 bg-stone-50 opacity-40",
                  else: "border-stone-200 bg-white"
                )
              ]}
            >
              <button
                type="button"
                phx-click="toggle_job"
                phx-value-id={job.id}
                phx-target={@myself}
                class="shrink-0 text-stone-300 transition hover:text-stone-500"
                title={if MapSet.member?(@hidden_job_ids, job.id), do: "Include", else: "Exclude"}
              >
                <.icon
                  name={if MapSet.member?(@hidden_job_ids, job.id), do: "hero-eye-slash", else: "hero-eye"}
                  class="h-4 w-4"
                />
              </button>
              <button
                type="button"
                phx-click="remove_job"
                phx-value-id={job.id}
                phx-target={@myself}
                class="shrink-0 text-stone-300 transition hover:text-red-400"
              >
                <.icon name="hero-minus-circle" class="h-4 w-4" />
              </button>
              <span class="min-w-0 flex-1 text-sm">
                <span class="font-medium text-stone-700">{format_service_type(job.service_type)}</span>
                <span class="mx-1 text-stone-300">·</span>
                <span class="text-stone-500">{format_scheduled(job.scheduled_at)}</span>
              </span>
              <input
                type="number"
                name={"invoice[job_amounts][#{job.id}]"}
                value={job.amount}
                step="0.01"
                min="0"
                class="w-24 rounded border border-stone-200 px-2 py-1 text-right text-sm focus:border-primary-400 focus:outline-none"
              />
            </div>
            <div
              :if={@selected_jobs == []}
              class="py-4 text-center text-sm text-stone-400"
            >
              No unpaid jobs for this customer.
            </div>
          </div>
        </div>

        <div :if={@customer_id && @customer_id != ""}>
          <div class="mb-2">
            <span class="text-xs font-semibold uppercase tracking-wide text-stone-500">Engagement</span>
          </div>
          <div
            :if={@selected_engagement}
            class={[
              "flex items-center gap-2 rounded-md border px-3 py-2 transition",
              if(@engagement_hidden,
                do: "border-stone-100 bg-stone-50 opacity-40",
                else: "border-stone-200 bg-white"
              )
            ]}
          >
            <button
              type="button"
              phx-click="toggle_engagement"
              phx-target={@myself}
              class="shrink-0 text-stone-300 transition hover:text-stone-500"
              title={if @engagement_hidden, do: "Include", else: "Exclude"}
            >
              <.icon
                name={if @engagement_hidden, do: "hero-eye-slash", else: "hero-eye"}
                class="h-4 w-4"
              />
            </button>
            <button
              type="button"
              phx-click="remove_engagement"
              phx-target={@myself}
              class="shrink-0 text-stone-300 transition hover:text-red-400"
            >
              <.icon name="hero-minus-circle" class="h-4 w-4" />
            </button>
            <span class="min-w-0 flex-1 text-sm">
              <span class="font-medium text-stone-700">{@selected_engagement.label}</span>
              <span :if={@selected_engagement.term} class="mx-1 text-stone-300">·</span>
              <span :if={@selected_engagement.term} class="text-stone-500">{@selected_engagement.term}</span>
            </span>
            <input type="hidden" name="invoice[engagement_id]" value={@selected_engagement.id} />
            <input
              type="number"
              name="invoice[engagement_amount]"
              value={@engagement_amount}
              step="0.01"
              min="0"
              class="w-24 rounded border border-stone-200 px-2 py-1 text-right text-sm focus:border-primary-400 focus:outline-none"
            />
          </div>
          <div :if={!@selected_engagement} class="py-2 text-sm text-stone-400">
            No engagement linked.
          </div>
        </div>

        <div>
          <div class="mb-2 flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-wide text-stone-500">Line Items</span>
            <button
              type="button"
              phx-click="add_line_item"
              phx-target={@myself}
              class="flex items-center gap-1 text-xs text-primary-600 hover:text-primary-700"
            >
              <.icon name="hero-plus-circle" class="h-3.5 w-3.5" />
              Add line item
            </button>
          </div>
          <div class="space-y-1">
            <div
              :for={item <- @custom_line_items}
              class="flex items-center gap-2 rounded-md border border-stone-200 bg-white px-3 py-2"
            >
              <button
                type="button"
                phx-click="remove_line_item"
                phx-value-id={item.id}
                phx-target={@myself}
                class="shrink-0 text-stone-300 transition hover:text-red-400"
              >
                <.icon name="hero-minus-circle" class="h-4 w-4" />
              </button>
              <input
                type="text"
                name={"invoice[line_items][#{item.id}][label]"}
                value={item.label}
                placeholder="Description"
                class="min-w-0 flex-1 rounded border border-stone-200 px-2 py-1 text-sm focus:border-primary-400 focus:outline-none"
              />
              <input
                type="number"
                name={"invoice[line_items][#{item.id}][amount]"}
                value={item.amount}
                step="0.01"
                min="0"
                placeholder="0.00"
                class="w-24 rounded border border-stone-200 px-2 py-1 text-right text-sm focus:border-primary-400 focus:outline-none"
              />
            </div>
            <div :if={@custom_line_items == []} class="py-2 text-sm text-stone-400">
              No custom line items.
            </div>
          </div>
        </div>

        <div>
          <label class="block text-xs font-medium text-stone-700 mb-1">Notes</label>
          <textarea
            name="invoice[notes]"
            rows="2"
            class="block w-full rounded-md border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          >{@params["notes"]}</textarea>
        </div>

        <div class="flex items-center justify-between border-t border-stone-100 pt-4">
          <span class="text-sm font-semibold text-stone-700">
            Total: {format_total(@selected_jobs, @hidden_job_ids, @engagement_amount, @engagement_hidden, @custom_line_items, @organisation.currency)}
          </span>
          <.button type="submit" variant={:primary} phx-disable-with="Saving…">
            Save Invoice
          </.button>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"invoice" => params}, socket) do
    customer_id = params["customer_id"]

    socket =
      if customer_id != "" and customer_id != socket.assigns.customer_id do
        {jobs, engagement} = load_customer_data(customer_id, socket.assigns.current_member)

        socket
        |> assign(:customer_id, customer_id)
        |> assign(:selected_jobs, jobs)
        |> assign(:hidden_job_ids, MapSet.new())
        |> assign(:selected_engagement, engagement)
        |> assign(:engagement_hidden, false)
        |> assign(:engagement_amount, default_engagement_amount(engagement))
      else
        socket
        |> sync_job_amounts(params["job_amounts"] || %{})
        |> sync_line_items(params["line_items"] || %{})
        |> assign(:engagement_amount, params["engagement_amount"] || socket.assigns.engagement_amount)
      end

    {:noreply, assign(socket, :params, params)}
  end

  @impl true
  def handle_event("toggle_job", %{"id" => id}, socket) do
    hidden = socket.assigns.hidden_job_ids

    updated =
      if MapSet.member?(hidden, id),
        do: MapSet.delete(hidden, id),
        else: MapSet.put(hidden, id)

    {:noreply, assign(socket, :hidden_job_ids, updated)}
  end

  @impl true
  def handle_event("toggle_engagement", _params, socket) do
    {:noreply, update(socket, :engagement_hidden, &(!&1))}
  end

  @impl true
  def handle_event("remove_job", %{"id" => id}, socket) do
    {:noreply, update(socket, :selected_jobs, &Enum.reject(&1, fn j -> j.id == id end))}
  end

  @impl true
  def handle_event("remove_engagement", _params, socket) do
    {:noreply, socket |> assign(:selected_engagement, nil) |> assign(:engagement_amount, "")}
  end

  @impl true
  def handle_event("add_line_item", _params, socket) do
    item = %{id: "li_#{:erlang.unique_integer([:positive])}", label: "", amount: ""}
    {:noreply, update(socket, :custom_line_items, &(&1 ++ [item]))}
  end

  @impl true
  def handle_event("remove_line_item", %{"id" => id}, socket) do
    {:noreply, update(socket, :custom_line_items, &Enum.reject(&1, fn i -> i.id == id end))}
  end

  @impl true
  def handle_event("save", %{"invoice" => params}, socket) do
    member = socket.assigns.current_member
    hidden_job_ids = socket.assigns.hidden_job_ids
    all_jobs = socket.assigns.selected_jobs
    visible_jobs = Enum.reject(all_jobs, fn j -> MapSet.member?(hidden_job_ids, j.id) end)
    engagement = socket.assigns.selected_engagement
    engagement_hidden = socket.assigns.engagement_hidden
    engagement_amount = if engagement_hidden, do: D.new(0), else: parse_decimal(params["engagement_amount"])
    custom_items = socket.assigns.custom_line_items

    job_total = Enum.reduce(visible_jobs, D.new(0), fn j, acc -> D.add(acc, parse_decimal(j.amount)) end)
    custom_total = Enum.reduce(custom_items, D.new(0), fn i, acc -> D.add(acc, parse_decimal(i.amount)) end)
    total = job_total |> D.add(engagement_amount) |> D.add(custom_total)

    line_items_to_save =
      Enum.map(custom_items, fn i ->
        %{"label" => i.label, "amount" => parse_decimal(i.amount)}
      end)

    attrs = %{
      reference: params["reference"],
      customer_id: params["customer_id"],
      engagement_id: if(!engagement_hidden && engagement, do: engagement.id),
      issued_on: parse_date(params["issued_on"]),
      due_on: parse_date(params["due_on"]),
      amount: total,
      status: safe_atom(params["status"], :draft),
      notes: params["notes"],
      line_items: line_items_to_save,
      organisation_id: member.organisation_id
    }

    case CRM.create_invoice(attrs, actor: member, tenant: member.organisation_id) do
      {:ok, invoice} ->
        for job <- visible_jobs do
          Orders.update_job(job.struct, %{invoice_id: invoice.id},
            actor: member,
            tenant: member.organisation_id
          )
        end

        notify_parent({:saved, invoice})

        {:noreply,
         socket
         |> put_flash(:info, "Invoice created.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not save invoice: #{inspect(error)}")}
    end
  end

  defp load_customers(socket) do
    member = socket.assigns.current_member

    customers =
      CRM.list_customers!(actor: member, tenant: member.organisation_id)
      |> Enum.map(fn c -> {"#{c.first_name} #{c.last_name}", c.id} end)
      |> Enum.sort_by(&elem(&1, 0))

    assign(socket, :customers, customers)
  rescue
    _ -> assign(socket, :customers, [])
  end

  defp load_customer_data(customer_id, member) do
    jobs = load_unpaid_jobs(customer_id, member)
    engagement = load_latest_engagement(customer_id, member)
    {jobs, engagement}
  end

  defp load_unpaid_jobs(customer_id, member) do
    Orders.Job
    |> filter(engagement.customer_id == ^customer_id and status in [:scheduled, :in_progress, :completed])
    |> Ash.Query.sort(scheduled_for: :asc)
    |> Ash.Query.load(:materials_cost)
    |> Ash.read!(actor: member, tenant: member.organisation_id)
    |> Enum.map(fn job ->
      %{
        id: job.id,
        struct: job,
        service_type: job.service_category || job.type,
        scheduled_at: job.scheduled_for,
        amount: job.materials_cost |> D.round(2) |> D.to_string()
      }
    end)
  rescue
    _ -> []
  end

  defp load_latest_engagement(customer_id, member) do
    CRM.Engagement
    |> filter(customer_id == ^customer_id and status != :cancelled)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.Query.load(:garden)
    |> Ash.read!(actor: member, tenant: member.organisation_id)
    |> List.first()
    |> case do
      nil -> nil
      e -> engagement_to_line(e)
    end
  rescue
    _ -> nil
  end

  defp engagement_to_line(e) do
    garden_name = e.garden && e.garden.name

    label =
      if garden_name && garden_name != "",
        do: garden_name,
        else: e.status |> Atom.to_string() |> String.replace("_", " ")

    term =
      cond do
        e.term_start && e.term_end -> "#{e.term_start} → #{e.term_end}"
        e.term_start -> "from #{e.term_start}"
        true -> nil
      end

    %{id: e.id, label: label, term: term, install_price: e.install_price, maintenance_price_annual: e.maintenance_price_annual}
  end

  defp default_engagement_amount(nil), do: ""

  defp default_engagement_amount(e) do
    install = e.install_price || D.new(0)
    maint = e.maintenance_price_annual || D.new(0)
    D.add(install, maint) |> D.round(2) |> D.to_string()
  end

  defp sync_job_amounts(socket, amounts_map) do
    updated =
      Enum.map(socket.assigns.selected_jobs, fn job ->
        case Map.fetch(amounts_map, job.id) do
          {:ok, amount} -> %{job | amount: amount}
          :error -> job
        end
      end)

    assign(socket, :selected_jobs, updated)
  end

  defp sync_line_items(socket, line_items_map) do
    updated =
      Enum.map(socket.assigns.custom_line_items, fn item ->
        case Map.fetch(line_items_map, item.id) do
          {:ok, data} ->
            %{item | label: data["label"] || item.label, amount: data["amount"] || item.amount}

          :error ->
            item
        end
      end)

    assign(socket, :custom_line_items, updated)
  end

  defp format_service_type(type) when is_atom(type) do
    type |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_scheduled(nil), do: "—"
  defp format_scheduled(%Date{} = d), do: Date.to_string(d)
  defp format_scheduled(%DateTime{} = dt), do: dt |> DateTime.to_date() |> Date.to_string()
  defp format_scheduled(other), do: to_string(other)

  defp format_total(jobs, hidden_job_ids, engagement_amount, engagement_hidden, custom_items, currency) do
    job_total =
      jobs
      |> Enum.reject(fn j -> MapSet.member?(hidden_job_ids, j.id) end)
      |> Enum.reduce(D.new(0), fn j, acc -> D.add(acc, parse_decimal(j.amount)) end)

    eng_total = if engagement_hidden, do: D.new(0), else: parse_decimal(engagement_amount)
    custom_total = Enum.reduce(custom_items, D.new(0), fn i, acc -> D.add(acc, parse_decimal(i.amount)) end)
    total = job_total |> D.add(eng_total) |> D.add(custom_total) |> D.round(2)
    "#{currency} #{total}"
  end

  defp parse_decimal(nil), do: D.new(0)
  defp parse_decimal(""), do: D.new(0)

  defp parse_decimal(s) when is_binary(s) do
    case D.parse(s) do
      {d, ""} -> d
      _ -> D.new(0)
    end
  end

  defp parse_decimal(%D{} = d), do: d

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(s) when is_binary(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp safe_atom(s, default) when is_binary(s) do
    String.to_existing_atom(s)
  rescue
    _ -> default
  end

  defp safe_atom(_, default), do: default

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
