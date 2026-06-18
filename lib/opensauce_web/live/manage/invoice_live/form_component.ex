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
    <div style="padding:0 16px;">
      <form id="invoice-form" phx-change="validate" phx-submit="save" phx-target={@myself} style="display:flex;flex-direction:column;gap:16px;padding-bottom:24px;">

        <%!-- reference + customer --%>
        <div style="display:flex;flex-direction:column;gap:12px;">
          <div>
            <label class="dark-label">Reference</label>
            <input
              type="text"
              name="invoice[reference]"
              value={@params["reference"]}
              class="dark-input"
              placeholder="INV-001"
              required
            />
          </div>
          <div>
            <label class="dark-label">Customer</label>
            <select name="invoice[customer_id]" class="dark-select">
              <option value="">Select customer…</option>
              <option :for={{label, id} <- @customers} value={id} selected={id == @customer_id}>
                {label}
              </option>
            </select>
          </div>
          <div style="display:flex;gap:10px;">
            <div style="flex:1;">
              <label class="dark-label">Issued</label>
              <input type="date" name="invoice[issued_on]" value={@params["issued_on"]} class="dark-input" required />
            </div>
            <div style="flex:1;">
              <label class="dark-label">Due <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
              <input type="date" name="invoice[due_on]" value={@params["due_on"]} class="dark-input" />
            </div>
          </div>
        </div>

        <%!-- jobs for selected customer --%>
        <div :if={@customer_id && @customer_id != ""}>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Uninvoiced jobs
            </p>
            <p style="font-size:12px;color:#6E675A;">{visible_job_count(@selected_jobs, @hidden_job_ids)} of {length(@selected_jobs)}</p>
          </div>
          <div style="display:flex;flex-direction:column;gap:6px;">
            <div
              :for={job <- @selected_jobs}
              style={"background:#16140E;border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 12px;display:flex;align-items:center;gap:10px;#{if MapSet.member?(@hidden_job_ids, job.id), do: "opacity:0.35;", else: ""}"}
            >
              <button
                type="button"
                phx-click="toggle_job"
                phx-value-id={job.id}
                phx-target={@myself}
                style="flex-shrink:0;color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                title={if MapSet.member?(@hidden_job_ids, job.id), do: "Include", else: "Exclude"}
              >
                <svg :if={!MapSet.member?(@hidden_job_ids, job.id)} width="16" height="16" fill="none" viewBox="0 0 24 24">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="#54B57E" stroke-width="2"/>
                  <circle cx="12" cy="12" r="3" stroke="#54B57E" stroke-width="2"/>
                </svg>
                <svg :if={MapSet.member?(@hidden_job_ids, job.id)} width="16" height="16" fill="none" viewBox="0 0 24 24">
                  <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  <line x1="1" y1="1" x2="23" y2="23" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                </svg>
              </button>
              <button
                type="button"
                phx-click="remove_job"
                phx-value-id={job.id}
                phx-target={@myself}
                style="flex-shrink:0;color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
              >
                <svg width="15" height="15" fill="none" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="10" stroke="#6E675A" stroke-width="2"/>
                  <line x1="8" y1="12" x2="16" y2="12" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                </svg>
              </button>
              <div style="flex:1;min-width:0;">
                <p style="font-size:13.5px;font-weight:600;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {format_job_label(job)}
                </p>
                <p style="font-size:11.5px;color:#9A9384;margin-top:1px;">{format_date(job.scheduled_at)}</p>
              </div>
              <input
                type="number"
                name={"invoice[job_amounts][#{job.id}]"}
                value={job.amount}
                step="0.01"
                min="0"
                style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
              />
            </div>
            <div :if={@selected_jobs == []} style="padding:12px 0;text-align:center;">
              <p style="font-size:13px;color:#6E675A;">No uninvoiced jobs for this customer.</p>
            </div>
          </div>
        </div>

        <%!-- engagement --%>
        <div :if={@customer_id && @customer_id != "" && @selected_engagement}>
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Engagement
          </p>
          <div style={"background:#16140E;border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 12px;display:flex;align-items:center;gap:10px;#{if @engagement_hidden, do: "opacity:0.35;", else: ""}"}>
            <button
              type="button"
              phx-click="toggle_engagement"
              phx-target={@myself}
              style="flex-shrink:0;color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
            >
              <svg :if={!@engagement_hidden} width="16" height="16" fill="none" viewBox="0 0 24 24">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="#54B57E" stroke-width="2"/>
                <circle cx="12" cy="12" r="3" stroke="#54B57E" stroke-width="2"/>
              </svg>
              <svg :if={@engagement_hidden} width="16" height="16" fill="none" viewBox="0 0 24 24">
                <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                <line x1="1" y1="1" x2="23" y2="23" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
              </svg>
            </button>
            <button
              type="button"
              phx-click="remove_engagement"
              phx-target={@myself}
              style="flex-shrink:0;color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
            >
              <svg width="15" height="15" fill="none" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="10" stroke="#6E675A" stroke-width="2"/>
                <line x1="8" y1="12" x2="16" y2="12" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
              </svg>
            </button>
            <div style="flex:1;min-width:0;">
              <p style="font-size:13.5px;font-weight:600;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {@selected_engagement.label}
              </p>
              <p :if={@selected_engagement.term} style="font-size:11.5px;color:#9A9384;margin-top:1px;">
                {@selected_engagement.term}
              </p>
            </div>
            <input type="hidden" name="invoice[engagement_id]" value={@selected_engagement.id} />
            <input
              type="number"
              name="invoice[engagement_amount]"
              value={@engagement_amount}
              step="0.01"
              min="0"
              style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
            />
          </div>
        </div>

        <%!-- custom line items --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Line items
            </p>
            <button
              type="button"
              phx-click="add_line_item"
              phx-target={@myself}
              style="font-size:12px;font-weight:600;color:#54B57E;background:none;border:none;cursor:pointer;display:flex;align-items:center;gap:4px;"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
                <path d="M12 5v14M5 12h14" stroke="#54B57E" stroke-width="2.5" stroke-linecap="round" />
              </svg>
              Add
            </button>
          </div>
          <div style="display:flex;flex-direction:column;gap:6px;">
            <div
              :for={item <- @custom_line_items}
              style="background:#16140E;border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:8px 12px;display:flex;align-items:center;gap:8px;"
            >
              <button
                type="button"
                phx-click="remove_line_item"
                phx-value-id={item.id}
                phx-target={@myself}
                style="flex-shrink:0;color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
              >
                <svg width="15" height="15" fill="none" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="10" stroke="#6E675A" stroke-width="2"/>
                  <line x1="8" y1="12" x2="16" y2="12" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                </svg>
              </button>
              <input
                type="text"
                name={"invoice[line_items][#{item.id}][label]"}
                value={item.label}
                placeholder="Description"
                style="flex:1;background:transparent;border:none;outline:none;font-size:13px;color:#F4EFE2;"
              />
              <input
                type="number"
                name={"invoice[line_items][#{item.id}][amount]"}
                value={item.amount}
                step="0.01"
                min="0"
                placeholder="0.00"
                style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
              />
            </div>
            <div :if={@custom_line_items == []} style="padding:4px 0;">
              <p style="font-size:13px;color:#6E675A;">No custom line items.</p>
            </div>
          </div>
        </div>

        <%!-- notes --%>
        <div>
          <label class="dark-label">Notes <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
          <textarea name="invoice[notes]" rows="2" class="dark-textarea">{@params["notes"]}</textarea>
        </div>

        <%!-- total + save --%>
        <div style="display:flex;align-items:center;justify-content:space-between;padding-top:4px;">
          <div>
            <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">Total</p>
            <p style="font-size:20px;font-weight:700;font-family:'Bricolage Grotesque',sans-serif;color:#F4EFE2;margin-top:2px;">
              {format_total(@selected_jobs, @hidden_job_ids, @engagement_amount, @engagement_hidden, @custom_line_items, @organisation.currency)}
            </p>
          </div>
          <.glow_button
            type="submit"
            valid={can_save?(@params, @customer_id)}
            phx-disable-with="Saving…"
          >
            Create invoice
          </.glow_button>
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
      status: :draft,
      notes: params["notes"],
      line_items: line_items_to_save,
      organisation_id: member.organisation_id
    }

    case CRM.create_invoice(attrs, actor: member, tenant: member.organisation_id) do
      {:ok, invoice} ->
        for job <- visible_jobs do
          Orders.assign_job_invoice(job.struct, %{invoice_id: invoice.id},
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
        {:noreply, put_flash(socket, :error, "Could not save: #{inspect(error)}")}
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
    jobs = load_uninvoiced_jobs(customer_id, member)
    engagement = load_latest_engagement(customer_id, member)
    {jobs, engagement}
  end

  defp load_uninvoiced_jobs(customer_id, member) do
    Orders.Job
    |> filter(
      engagement.customer_id == ^customer_id and
        status in [:scheduled, :in_progress, :completed] and
        is_nil(invoice_id)
    )
    |> Ash.Query.sort(scheduled_for: :asc)
    |> Ash.Query.load([:materials_cost, :garden])
    |> Ash.read!(actor: member, tenant: member.organisation_id)
    |> Enum.map(fn job ->
      %{
        id: job.id,
        struct: job,
        service_type: job.service_category || job.type,
        garden_name: job.garden && job.garden.name,
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
      cond do
        e.scope_title && e.scope_title != "" -> e.scope_title
        garden_name && garden_name != "" -> garden_name
        true -> e.status |> Atom.to_string() |> String.replace("_", " ")
      end

    term =
      cond do
        e.term_start && e.term_end -> "#{e.term_start} → #{e.term_end}"
        e.term_start -> "from #{e.term_start}"
        true -> nil
      end

    %{
      id: e.id,
      label: label,
      term: term,
      install_price: e.install_price,
      maintenance_price_annual: e.maintenance_price_annual
    }
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

  defp visible_job_count(jobs, hidden_job_ids) do
    Enum.count(jobs, fn j -> not MapSet.member?(hidden_job_ids, j.id) end)
  end

  defp can_save?(params, customer_id) do
    ref = String.trim(params["reference"] || "")
    ref != "" && customer_id not in [nil, ""]
  end

  defp format_job_label(%{service_type: type, garden_name: garden}) when is_binary(garden) and garden != "" do
    "#{format_service_type(type)} to #{garden}"
  end

  defp format_job_label(%{service_type: type}), do: format_service_type(type)

  defp format_service_type(type) when is_atom(type) do
    type |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_service_type(type) when is_binary(type) do
    type |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_service_type(_), do: "Job"

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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
