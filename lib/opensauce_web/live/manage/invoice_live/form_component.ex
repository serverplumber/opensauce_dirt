defmodule OpenSauceWeb.InvoiceLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  import Ash.Query

  alias OpenSauce.CRM
  alias OpenSauce.Work
  alias Decimal, as: D

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:customer_id, fn -> nil end)
      |> assign_new(:groups, fn -> [] end)
      |> assign_new(:hidden_job_ids, fn -> MapSet.new() end)
      |> assign_new(:custom_line_items, fn -> [] end)
      |> assign_new(:params, fn ->
        %{
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

        <%!-- customer --%>
        <div style="display:flex;flex-direction:column;gap:12px;">
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

        <%!-- engagement groups --%>
        <div :if={@customer_id && @customer_id != "" && @groups != []}>
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:8px;">
            Work
          </p>
          <div style="display:flex;flex-direction:column;gap:10px;">
            <div
              :for={group <- @groups}
              style="background:#16140E;border:1px solid rgba(52,48,37,0.58);border-radius:12px;overflow:hidden;"
            >
              <%!-- engagement header --%>
              <div
                :if={group.engagement}
                style={"display:flex;align-items:center;gap:10px;padding:10px 12px;#{if group.jobs != [] or group.custom_items != [], do: "border-bottom:1px solid rgba(52,48,37,0.4);", else: ""}#{if group.engagement.hidden, do: "opacity:0.45;", else: ""}"}
              >
                <button
                  type="button"
                  phx-click="toggle_engagement"
                  phx-value-id={group.engagement.id}
                  phx-target={@myself}
                  style="flex-shrink:0;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                >
                  <svg :if={!group.engagement.hidden} width="15" height="15" fill="none" viewBox="0 0 24 24">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="#54B57E" stroke-width="2"/>
                    <circle cx="12" cy="12" r="3" stroke="#54B57E" stroke-width="2"/>
                  </svg>
                  <svg :if={group.engagement.hidden} width="15" height="15" fill="none" viewBox="0 0 24 24">
                    <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                    <line x1="1" y1="1" x2="23" y2="23" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="remove_group"
                  phx-value-id={group.engagement.id}
                  phx-target={@myself}
                  style="flex-shrink:0;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                >
                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <circle cx="12" cy="12" r="10" stroke="#6E675A" stroke-width="2"/>
                    <line x1="8" y1="12" x2="16" y2="12" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
                <div style="flex:1;min-width:0;">
                  <p style="font-size:13px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {group.engagement.label}
                  </p>
                  <p :if={group.engagement.term} style="font-size:11px;color:#9A9384;margin-top:1px;">
                    {group.engagement.term}
                  </p>
                </div>
                <input
                  type="number"
                  name={"invoice[engagement_amounts][#{group.engagement.id}]"}
                  value={group.engagement.amount}
                  step="0.01"
                  min="0"
                  style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.4);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
                />
              </div>

              <%!-- jobs in group --%>
              <div
                :for={{job, idx} <- Enum.with_index(group.jobs)}
                style={"display:flex;align-items:center;gap:10px;padding:8px 12px 8px 14px;#{if idx > 0 or group.engagement != nil, do: "border-top:1px solid rgba(52,48,37,0.3);", else: ""}#{if MapSet.member?(@hidden_job_ids, job.id), do: "opacity:0.35;", else: ""}"}
              >
                <button
                  type="button"
                  phx-click="toggle_job"
                  phx-value-id={job.id}
                  phx-target={@myself}
                  style="flex-shrink:0;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                >
                  <svg :if={!MapSet.member?(@hidden_job_ids, job.id)} width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="#54B57E" stroke-width="2"/>
                    <circle cx="12" cy="12" r="3" stroke="#54B57E" stroke-width="2"/>
                  </svg>
                  <svg :if={MapSet.member?(@hidden_job_ids, job.id)} width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                    <line x1="1" y1="1" x2="23" y2="23" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="remove_job"
                  phx-value-id={job.id}
                  phx-target={@myself}
                  style="flex-shrink:0;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                >
                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <circle cx="12" cy="12" r="10" stroke="#6E675A" stroke-width="2"/>
                    <line x1="8" y1="12" x2="16" y2="12" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
                <div style="flex:1;min-width:0;">
                  <p style="font-size:12.5px;font-weight:500;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    {format_job_label(job)}
                  </p>
                  <p :if={job.scheduled_at} style="font-size:11px;color:#6E675A;margin-top:1px;">{format_date(job.scheduled_at)}</p>
                </div>
                <input
                  type="number"
                  name={"invoice[job_amounts][#{job.id}]"}
                  value={job.amount}
                  step="0.01"
                  min="0"
                  style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.4);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
                />
              </div>
              <%!-- custom lines in group --%>
              <div
                :for={item <- group.custom_items}
                style={"display:flex;align-items:center;gap:10px;padding:8px 12px 8px 14px;border-top:1px solid rgba(52,48,37,0.3);#{if item.hidden, do: "opacity:0.35;", else: ""}"}
              >
                <button
                  type="button"
                  phx-click="toggle_group_line"
                  phx-value-id={item.id}
                  phx-value-eng={group.engagement.id}
                  phx-target={@myself}
                  style="flex-shrink:0;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                >
                  <svg :if={!item.hidden} width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="#54B57E" stroke-width="2"/>
                    <circle cx="12" cy="12" r="3" stroke="#54B57E" stroke-width="2"/>
                  </svg>
                  <svg :if={item.hidden} width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                    <line x1="1" y1="1" x2="23" y2="23" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="remove_group_line"
                  phx-value-id={item.id}
                  phx-value-eng={group.engagement.id}
                  phx-target={@myself}
                  style="flex-shrink:0;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                >
                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24">
                    <circle cx="12" cy="12" r="10" stroke="#6E675A" stroke-width="2"/>
                    <line x1="8" y1="12" x2="16" y2="12" stroke="#6E675A" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
                <input
                  type="text"
                  name={"invoice[group_lines][#{group.engagement.id}][#{item.id}][label]"}
                  value={item.label}
                  placeholder="Description"
                  style="flex:1;min-width:0;background:transparent;border:none;outline:none;font-size:12.5px;color:#F4EFE2;"
                />
                <input
                  type="number"
                  name={"invoice[group_lines][#{group.engagement.id}][#{item.id}][amount]"}
                  value={item.amount}
                  step="0.01"
                  min="0"
                  placeholder="0.00"
                  style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.4);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
                />
              </div>
              <%!-- add line --%>
              <div
                :if={group.engagement}
                style="padding:7px 12px 7px 14px;border-top:1px solid rgba(52,48,37,0.3);"
              >
                <button
                  type="button"
                  phx-click="add_group_line"
                  phx-value-id={group.engagement.id}
                  phx-target={@myself}
                  style="font-size:12px;font-weight:600;color:#54B57E;background:none;border:none;cursor:pointer;display:flex;align-items:center;gap:4px;padding:0;"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none">
                    <path d="M12 5v14M5 12h14" stroke="#54B57E" stroke-width="2.5" stroke-linecap="round" />
                  </svg>
                  Add line
                </button>
              </div>
            </div>

            <div :if={@groups == []} style="padding:12px 0;text-align:center;">
              <p style="font-size:13px;color:#6E675A;">No uninvoiced work for this customer.</p>
            </div>
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
                <svg width="14" height="14" fill="none" viewBox="0 0 24 24">
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
                style="width:72px;background:#211E16;border:1px solid rgba(52,48,37,0.4);border-radius:8px;padding:5px 8px;font-size:13px;color:#F4EFE2;text-align:right;outline:none;"
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
              {format_total(@groups, @hidden_job_ids, @custom_line_items, @organisation.currency)}
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
        groups = load_customer_data(customer_id, socket.assigns.current_member)

        socket
        |> assign(:customer_id, customer_id)
        |> assign(:groups, groups)
        |> assign(:hidden_job_ids, MapSet.new())
      else
        socket
        |> sync_job_amounts(params["job_amounts"] || %{})
        |> sync_engagement_amounts(params["engagement_amounts"] || %{})
        |> sync_group_lines(params["group_lines"] || %{})
        |> sync_line_items(params["line_items"] || %{})
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
  def handle_event("toggle_engagement", %{"id" => id}, socket) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        if g.engagement && g.engagement.id == id,
          do: %{g | engagement: %{g.engagement | hidden: !g.engagement.hidden}},
          else: g
      end)

    {:noreply, assign(socket, :groups, updated)}
  end

  @impl true
  def handle_event("remove_job", %{"id" => id}, socket) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        %{g | jobs: Enum.reject(g.jobs, &(&1.id == id))}
      end)

    {:noreply, assign(socket, :groups, updated)}
  end

  @impl true
  def handle_event("remove_group", %{"id" => engagement_id}, socket) do
    updated = Enum.reject(socket.assigns.groups, fn g ->
      g.engagement && g.engagement.id == engagement_id
    end)

    {:noreply, assign(socket, :groups, updated)}
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
  def handle_event("add_group_line", %{"id" => eng_id}, socket) do
    item = %{id: "gl_#{:erlang.unique_integer([:positive])}", label: "", amount: "", hidden: false}

    updated =
      Enum.map(socket.assigns.groups, fn g ->
        if g.engagement && g.engagement.id == eng_id,
          do: %{g | custom_items: g.custom_items ++ [item]},
          else: g
      end)

    {:noreply, assign(socket, :groups, updated)}
  end

  @impl true
  def handle_event("toggle_group_line", %{"id" => item_id, "eng" => eng_id}, socket) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        if g.engagement && g.engagement.id == eng_id do
          items = Enum.map(g.custom_items, fn i ->
            if i.id == item_id, do: %{i | hidden: !i.hidden}, else: i
          end)
          %{g | custom_items: items}
        else
          g
        end
      end)

    {:noreply, assign(socket, :groups, updated)}
  end

  @impl true
  def handle_event("remove_group_line", %{"id" => item_id, "eng" => eng_id}, socket) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        if g.engagement && g.engagement.id == eng_id,
          do: %{g | custom_items: Enum.reject(g.custom_items, &(&1.id == item_id))},
          else: g
      end)

    {:noreply, assign(socket, :groups, updated)}
  end

  @impl true
  def handle_event("save", %{"invoice" => params}, socket) do
    member = socket.assigns.current_member
    hidden_job_ids = socket.assigns.hidden_job_ids
    groups = socket.assigns.groups
    custom_items = socket.assigns.custom_line_items
    engagement_amounts = params["engagement_amounts"] || %{}

    group_lines_params = params["group_lines"] || %{}

    line_items_from_groups =
      Enum.flat_map(groups, fn g ->
        group_id = g.engagement && g.engagement.id

        eng_items =
          if g.engagement && !g.engagement.hidden do
            amount = parse_decimal(Map.get(engagement_amounts, g.engagement.id, g.engagement.amount))

            [%{
              "label" => g.engagement.label,
              "amount" => D.to_string(amount),
              "type" => "engagement",
              "group_id" => group_id
            }]
          else
            []
          end

        job_items =
          g.jobs
          |> Enum.reject(&MapSet.member?(hidden_job_ids, &1.id))
          |> Enum.map(fn j ->
            item = %{
              "label" => format_job_label(j, g.engagement),
              "amount" => D.to_string(parse_decimal(j.amount)),
              "type" => "job"
            }

            item = if group_id, do: Map.put(item, "group_id", group_id), else: item
            if j.scheduled_at, do: Map.put(item, "date", format_date(j.scheduled_at)), else: item
          end)

        group_custom_items =
          if group_id do
            eng_line_params = Map.get(group_lines_params, group_id, %{})

            g.custom_items
            |> Enum.reject(& &1.hidden)
            |> Enum.map(fn i ->
              data = Map.get(eng_line_params, i.id, %{})
              label = data["label"] || i.label
              amount = D.to_string(parse_decimal(data["amount"] || i.amount))
              %{"label" => label, "amount" => amount, "type" => "custom", "group_id" => group_id}
            end)
          else
            []
          end

        eng_items ++ job_items ++ group_custom_items
      end)

    custom_line_items_saved =
      Enum.map(custom_items, fn i ->
        %{"label" => i.label, "amount" => D.to_string(parse_decimal(i.amount)), "type" => "custom"}
      end)

    line_items_to_save = line_items_from_groups ++ custom_line_items_saved

    eng_total =
      Enum.reduce(groups, D.new(0), fn g, acc ->
        if g.engagement && !g.engagement.hidden do
          amount = parse_decimal(Map.get(engagement_amounts, g.engagement.id, g.engagement.amount))
          D.add(acc, amount)
        else
          acc
        end
      end)

    job_total =
      groups
      |> Enum.flat_map(& &1.jobs)
      |> Enum.reject(&MapSet.member?(hidden_job_ids, &1.id))
      |> Enum.reduce(D.new(0), fn j, acc -> D.add(acc, parse_decimal(j.amount)) end)

    custom_total =
      Enum.reduce(custom_items, D.new(0), fn i, acc -> D.add(acc, parse_decimal(i.amount)) end)

    group_custom_total =
      Enum.reduce(groups, D.new(0), fn g, acc ->
        Enum.reduce(g.custom_items, acc, fn i, a ->
          if i.hidden, do: a, else: D.add(a, parse_decimal(i.amount))
        end)
      end)

    total = eng_total |> D.add(job_total) |> D.add(custom_total) |> D.add(group_custom_total)

    all_visible_jobs =
      groups
      |> Enum.flat_map(& &1.jobs)
      |> Enum.reject(&MapSet.member?(hidden_job_ids, &1.id))

    attrs = %{
      customer_id: params["customer_id"],
      issued_on: parse_date(params["issued_on"]),
      due_on: parse_date(params["due_on"]),
      amount: total,
      status: :draft,
      notes: params["notes"],
      line_items: line_items_to_save,
      organisation_id: member.organisation_id
    }

    superseded_void_ids =
      all_visible_jobs
      |> Enum.map(& &1.struct.invoice_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case CRM.create_invoice(attrs, actor: member, tenant: member.organisation_id) do
      {:ok, invoice} ->
        for job <- all_visible_jobs do
          Work.assign_job_invoice(job.struct, %{invoice_id: invoice.id},
            actor: member,
            tenant: member.organisation_id
          )
        end

        for void_id <- superseded_void_ids do
          with {:ok, old_inv} <-
                 CRM.get_invoice_by_id(void_id,
                   actor: member,
                   tenant: member.organisation_id,
                   load: [:jobs]
                 ),
               true <- old_inv.status == :void,
               true <- old_inv.jobs == [] do
            CRM.destroy_invoice(old_inv, actor: member, tenant: member.organisation_id)
          end
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

    customer_ids =
      Work.Job
      |> filter(is_nil(invoice_id) or invoice.status == :void)
      |> Ash.Query.load(:engagement)
      |> Ash.read!(actor: member, tenant: member.organisation_id)
      |> Enum.flat_map(fn job ->
        case job.engagement do
          %{customer_id: id} when not is_nil(id) -> [id]
          _ -> []
        end
      end)
      |> MapSet.new()

    customers =
      CRM.list_customers!(actor: member, tenant: member.organisation_id)
      |> Enum.filter(&MapSet.member?(customer_ids, &1.id))
      |> Enum.map(fn c -> {"#{c.first_name} #{c.last_name}", c.id} end)
      |> Enum.sort_by(&elem(&1, 0))

    assign(socket, :customers, customers)
  rescue
    _ -> assign(socket, :customers, [])
  end

  defp load_customer_data(customer_id, member) do
    jobs = load_uninvoiced_jobs(customer_id, member)

    jobs
    |> Enum.group_by(fn j -> j.engagement && j.engagement.id end)
    |> Enum.map(fn {_id, group_jobs} ->
      eng_line =
        case List.first(group_jobs).engagement do
          nil -> nil
          e -> Map.merge(e, %{amount: default_engagement_amount(e), hidden: false})
        end

      %{engagement: eng_line, jobs: group_jobs, custom_items: []}
    end)
    |> Enum.sort_by(fn g ->
      g.jobs
      |> Enum.map(& &1.scheduled_at)
      |> Enum.filter(& &1)
      |> case do
        [] -> ~D[9999-12-31]
        dates -> Enum.min(dates)
      end
    end)
  end

  defp load_uninvoiced_jobs(customer_id, member) do
    Work.Job
    |> filter(engagement.customer_id == ^customer_id and (is_nil(invoice_id) or invoice.status == :void))
    |> Ash.Query.sort(scheduled_for: :asc)
    |> Ash.Query.load([:materials_cost, :garden, engagement: [:garden]])
    |> Ash.read!(actor: member, tenant: member.organisation_id)
    |> Enum.map(fn job ->
      eng_line = if job.engagement, do: engagement_to_line(job.engagement), else: nil

      %{
        id: job.id,
        struct: job,
        service_type: job.service_category || job.type,
        garden_name: job.garden && job.garden.name,
        scheduled_at: job.scheduled_for,
        amount: job.materials_cost |> D.round(2) |> D.to_string(),
        engagement: eng_line
      }
    end)
  rescue
    _ -> []
  end

  defp engagement_to_line(e) do
    garden_name = e.garden && e.garden.name

    label =
      cond do
        e.scope_title && e.scope_title != "" && garden_name && garden_name != "" ->
          "#{e.scope_title} · #{garden_name}"
        e.scope_title && e.scope_title != "" ->
          e.scope_title
        garden_name && garden_name != "" ->
          garden_name
        true ->
          e.status |> Atom.to_string() |> String.replace("_", " ")
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

  defp default_engagement_amount(%{install_price: i, maintenance_price_annual: m}) do
    install = i || D.new(0)
    maint = m || D.new(0)
    D.add(install, maint) |> D.round(2) |> D.to_string()
  end

  defp default_engagement_amount(_), do: ""

  defp sync_job_amounts(socket, amounts_map) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        %{g | jobs: Enum.map(g.jobs, fn job ->
          case Map.fetch(amounts_map, job.id) do
            {:ok, amount} -> %{job | amount: amount}
            :error -> job
          end
        end)}
      end)

    assign(socket, :groups, updated)
  end

  defp sync_engagement_amounts(socket, amounts_map) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        if g.engagement do
          case Map.fetch(amounts_map, g.engagement.id) do
            {:ok, amount} -> %{g | engagement: %{g.engagement | amount: amount}}
            :error -> g
          end
        else
          g
        end
      end)

    assign(socket, :groups, updated)
  end

  defp sync_group_lines(socket, group_lines_map) do
    updated =
      Enum.map(socket.assigns.groups, fn g ->
        if g.engagement do
          eng_data = Map.get(group_lines_map, g.engagement.id, %{})

          items =
            Enum.map(g.custom_items, fn item ->
              case Map.fetch(eng_data, item.id) do
                {:ok, data} ->
                  %{item | label: data["label"] || item.label, amount: data["amount"] || item.amount}

                :error ->
                  item
              end
            end)

          %{g | custom_items: items}
        else
          g
        end
      end)

    assign(socket, :groups, updated)
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

  defp can_save?(_params, customer_id), do: customer_id not in [nil, ""]

  defp format_job_label(%{service_type: type}, _engagement \\ nil) do
    format_service_type(type)
  end

  defp format_service_type(type) when is_atom(type) do
    type |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_service_type(type) when is_binary(type) do
    type |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_service_type(_), do: "Job"

  defp format_total(groups, hidden_job_ids, custom_items, currency) do
    eng_total =
      Enum.reduce(groups, D.new(0), fn g, acc ->
        if g.engagement && !g.engagement.hidden,
          do: D.add(acc, parse_decimal(g.engagement.amount)),
          else: acc
      end)

    job_total =
      groups
      |> Enum.flat_map(& &1.jobs)
      |> Enum.reject(&MapSet.member?(hidden_job_ids, &1.id))
      |> Enum.reduce(D.new(0), fn j, acc -> D.add(acc, parse_decimal(j.amount)) end)

    group_custom_total =
      Enum.reduce(groups, D.new(0), fn g, acc ->
        Enum.reduce(g.custom_items, acc, fn i, a ->
          if i.hidden, do: a, else: D.add(a, parse_decimal(i.amount))
        end)
      end)

    ungrouped_total =
      Enum.reduce(custom_items, D.new(0), fn i, acc -> D.add(acc, parse_decimal(i.amount)) end)

    total =
      eng_total
      |> D.add(job_total)
      |> D.add(group_custom_total)
      |> D.add(ungrouped_total)
      |> D.round(2)

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
