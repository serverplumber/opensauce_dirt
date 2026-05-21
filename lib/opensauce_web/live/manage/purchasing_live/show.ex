defmodule OpenSauceWeb.PurchasingLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias Decimal, as: D
  alias OpenSauce.Inventory
  alias OpenSauce.Inventory.Receiving
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@po.reference}
      <:subtitle>
        <span class={["rounded px-2 py-0.5 text-xs font-medium", status_class(@po.status)]}>
          {Phoenix.Naming.humanize(@po.status)}
        </span>
      </:subtitle>
      <:actions>
        <.link :if={@po.status == :draft} patch={~p"/manage/purchasing/#{@po.reference}/add_item"}>
          <.button variant={:outline}>Add Item</.button>
        </.link>
        <.button
          :if={@po.status == :draft}
          phx-click="mark_ordered"
          variant={:primary}
          phx-disable-with="Saving…"
        >
          Mark Ordered
        </.button>
        <.link :if={@po.status == :confirmed} navigate={~p"/manage/purchasing/#{@po.reference}/lineup"}>
          <.button variant={:primary}>Go to Lineup</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4">
      <div :if={@live_action == :show}>
        <.list>
          <:item title="Reference"><.kbd>{@po.reference}</.kbd></:item>
          <:item title="Supplier">{@po.supplier.name}</:item>
          <:item title="Status">{Phoenix.Naming.humanize(@po.status)}</:item>
          <:item title="Ordered">{format_time(@po.ordered_at, @time_zone)}</:item>
          <:item title="Received">{format_time(@po.received_at, @time_zone)}</:item>
        </.list>
      </div>

      <div :if={@live_action in [:items, :add_item]}>
        <div :if={@po.status == :ordered}>
          <p class="mb-3 text-sm text-stone-500">
            Enter the quantity each item the supplier confirmed they have set aside.
          </p>
          <form phx-submit="confirm_items" id="confirm-form">
            <div class="overflow-x-auto rounded-md border border-stone-200">
              <table class="min-w-full divide-y divide-stone-200 text-sm">
                <thead class="bg-stone-50">
                  <tr>
                    <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">SKU</th>
                    <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">Plant</th>
                    <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wide text-stone-500">Ordered</th>
                    <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wide text-stone-500">Confirmed</th>
                    <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wide text-stone-500">Price</th>
                    <th class="px-3 py-2"></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-100 bg-white">
                  <tr :for={item <- @po.items}>
                    <td class="px-3 py-2 font-mono text-stone-700">{item.supplier_sku}</td>
                    <td class="px-3 py-2 text-stone-600">{plant_label(item)}</td>
                    <td class="px-3 py-2 text-right text-stone-600">{fmt_qty(item.quantity)}</td>
                    <td class="px-3 py-2 text-right">
                      <input
                        type="number"
                        name={"confirm[#{item.id}]"}
                        value={fmt_qty(item.confirmed_qty || item.quantity)}
                        step="1"
                        min="0"
                        class="w-20 rounded border border-stone-300 px-2 py-1 text-right text-sm focus:border-primary-400 focus:outline-none"
                      />
                    </td>
                    <td class="px-3 py-2 text-right text-stone-500">
                      {format_money(@settings.currency, item.unit_price || D.new(0))}
                    </td>
                    <td class="px-3 py-2">
                      <span :if={item.is_reservation} class="rounded bg-violet-50 px-1.5 py-0.5 text-xs text-violet-600">
                        cherry-pick
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="mt-4 flex justify-end">
              <.button type="submit" variant={:primary} phx-disable-with="Saving…">
                Supplier Confirmed
              </.button>
            </div>
          </form>
        </div>

        <div :if={@po.status != :ordered}>
          <.table id="po-items" rows={@po.items}>
            <:col :let={i} label="SKU">
              <span class="font-mono">{i.supplier_sku}</span>
            </:col>
            <:col :let={i} label="Plant">{plant_label(i)}</:col>
            <:col :let={i} label="Ordered">{fmt_qty(i.quantity)}</:col>
            <:col :let={i} label="Confirmed">{fmt_qty(i.confirmed_qty) || "—"}</:col>
            <:col :if={@po.status == :received} :let={i} label="Received">
              {fmt_qty(i.received_qty) || "—"}
            </:col>
            <:col :let={i} label="Price">
              {format_money(@settings.currency, i.unit_price || D.new(0))}
            </:col>
            <:col :let={i} label="">
              <span :if={i.is_reservation} class="rounded bg-violet-50 px-1.5 py-0.5 text-xs text-violet-600">
                cherry-pick
              </span>
            </:col>
          </.table>
        </div>
      </div>

      <div :if={@live_action == :lineup}>
        <div :if={@po.status == :confirmed}>
          <p class="mb-4 text-sm text-stone-500">
            Walk through each item and enter the quantity you're taking. Cherry-pick items are plants to inspect individually.
          </p>
          <form phx-submit="finalize_pickup" id="lineup-form">
            <div class="space-y-2">
              <div
                :for={item <- @po.items}
                class="flex items-center gap-4 rounded-lg border border-stone-200 bg-white px-4 py-3"
              >
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2">
                    <span class="font-mono text-sm font-medium text-stone-800">{item.supplier_sku}</span>
                    <span :if={item.is_reservation} class="rounded bg-violet-50 px-1.5 py-0.5 text-xs text-violet-600">
                      cherry-pick
                    </span>
                  </div>
                  <div class="text-sm text-stone-400">{plant_label(item)}</div>
                </div>
                <div class="text-sm text-stone-400">
                  <span class="font-medium text-stone-600">{fmt_qty(item.confirmed_qty)}</span> confirmed
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-xs text-stone-400">Taking</span>
                  <input
                    type="number"
                    name={"lineup[#{item.id}]"}
                    value={fmt_qty(item.confirmed_qty || item.quantity)}
                    step="1"
                    min="0"
                    class="w-20 rounded border border-stone-300 px-2 py-1 text-right text-sm focus:border-primary-400 focus:outline-none"
                  />
                </div>
              </div>
            </div>
            <div class="mt-6 flex justify-end">
              <.button type="submit" variant={:primary} phx-disable-with="Finalizing…">
                Finalize Pickup
              </.button>
            </div>
          </form>
        </div>

        <div :if={@po.status == :received} class="space-y-2">
          <div
            :for={item <- @po.items}
            class="flex items-center gap-4 rounded-lg border border-stone-100 bg-stone-50 px-4 py-3"
          >
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <span class="font-mono text-sm font-medium text-stone-700">{item.supplier_sku}</span>
                <span :if={item.is_reservation} class="rounded bg-violet-50 px-1.5 py-0.5 text-xs text-violet-600">
                  cherry-pick
                </span>
              </div>
              <div class="text-sm text-stone-400">{plant_label(item)}</div>
            </div>
            <div class="flex gap-6 text-sm">
              <div class="text-stone-400">
                Confirmed: <span class="font-medium text-stone-600">{fmt_qty(item.confirmed_qty)}</span>
              </div>
              <div class="text-stone-400">
                Received: <span class="font-medium text-stone-800">{fmt_qty(item.received_qty)}</span>
              </div>
            </div>
          </div>
        </div>

        <div :if={@po.status not in [:confirmed, :received]} class="py-8 text-center text-sm text-stone-400">
          Lineup is available once the supplier has confirmed availability.
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action == :add_item}
      id="po-item-modal"
      show
      title={"Add Item to #{@po.reference}"}
      on_cancel={JS.patch(~p"/manage/purchasing/#{@po.reference}/items")}
    >
      <.live_component
        module={OpenSauceWeb.PurchasingLive.PurchaseOrderItemFormComponent}
        id="po-item-form"
        current_member={@current_member}
        materials={@materials}
        supplier={@po.supplier}
        po_id={@po.id}
        purchase_order_item={nil}
        patch={~p"/manage/purchasing/#{@po.reference}/items"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    materials =
      Inventory.list_materials!(
        actor: socket.assigns.current_member,
        tenant: socket.assigns.current_member.organisation_id
      )

    {:ok, assign(socket, materials: materials)}
  end

  @impl true
  def handle_params(%{"po_ref" => ref}, _uri, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id, load: po_load()]

    case Inventory.get_purchase_order_by_reference(ref, opts) do
      {:ok, nil} ->
        {:noreply,
         socket
         |> put_flash(:error, "Purchase order not found")
         |> push_navigate(to: ~p"/manage/purchasing")}

      {:ok, po} ->
        live_action = socket.assigns.live_action
        tabs_links = build_tabs(po, live_action)

        {:noreply,
         socket
         |> assign(:po, po)
         |> assign(:tabs_links, tabs_links)
         |> Navigation.assign(:purchasing, po_trail(po, live_action))}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to load purchase order")
         |> push_navigate(to: ~p"/manage/purchasing")}
    end
  end

  @impl true
  def handle_event("mark_ordered", _params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    case Inventory.mark_purchase_order_ordered(socket.assigns.po, opts) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_po()
         |> put_flash(:info, "PO marked as ordered.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update status.")}
    end
  end

  @impl true
  def handle_event("confirm_items", %{"confirm" => confirmations}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    for item <- socket.assigns.po.items do
      qty = parse_decimal(Map.get(confirmations, item.id))
      Inventory.confirm_purchase_order_item(item, %{confirmed_qty: qty}, opts)
    end

    case Inventory.confirm_purchase_order(socket.assigns.po, opts) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_po()
         |> put_flash(:info, "Supplier confirmation saved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save confirmations.")}
    end
  end

  @impl true
  def handle_event("finalize_pickup", %{"lineup" => received_qtys}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    for item <- socket.assigns.po.items do
      qty = parse_decimal(Map.get(received_qtys, item.id))
      Inventory.receive_purchase_order_item(item, %{received_qty: qty}, opts)
    end

    case Receiving.receive_po(socket.assigns.po.id, actor: member, tenant: member.organisation_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pickup finalized. Stock updated.")
         |> push_navigate(to: ~p"/manage/purchasing/#{socket.assigns.po.reference}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not finalize pickup.")}
    end
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    {:noreply,
     socket
     |> reload_po()
     |> put_flash(:info, "Item added.")}
  end

  defp reload_po(socket) do
    member = socket.assigns.current_member
    po = Inventory.get_purchase_order_by_reference!(
      socket.assigns.po.reference,
      actor: member,
      tenant: member.organisation_id,
      load: po_load()
    )
    live_action = socket.assigns.live_action
    socket
    |> assign(:po, po)
    |> assign(:tabs_links, build_tabs(po, live_action))
  end

  defp po_load do
    [:supplier, items: [material: [:unit], supplier_catalogue_item: []]]
  end

  defp build_tabs(po, live_action) do
    base = [
      %{
        label: "Overview",
        navigate: ~p"/manage/purchasing/#{po.reference}",
        active: live_action == :show
      },
      %{
        label: "Items",
        navigate: ~p"/manage/purchasing/#{po.reference}/items",
        active: live_action in [:items, :add_item]
      }
    ]

    if po.status in [:confirmed, :received] do
      base ++
        [
          %{
            label: "Lineup",
            navigate: ~p"/manage/purchasing/#{po.reference}/lineup",
            active: live_action == :lineup
          }
        ]
    else
      base
    end
  end

  defp plant_label(%{supplier_catalogue_item: %{latin_name: ln, cultivar: cv}})
       when not is_nil(ln) do
    [ln, cv] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp plant_label(%{material: %{name: name}}) when not is_nil(name), do: name
  defp plant_label(_), do: "—"

  defp fmt_qty(nil), do: nil
  defp fmt_qty(%D{} = d), do: D.to_string(d)
  defp fmt_qty(n), do: to_string(n)

  defp parse_decimal(nil), do: D.new(0)
  defp parse_decimal(""), do: D.new(0)

  defp parse_decimal(s) when is_binary(s) do
    case D.parse(s) do
      {d, ""} -> d
      _ -> D.new(0)
    end
  end

  defp status_class(:draft), do: "bg-stone-100 text-stone-600"
  defp status_class(:ordered), do: "bg-amber-100 text-amber-700"
  defp status_class(:confirmed), do: "bg-blue-100 text-blue-700"
  defp status_class(:received), do: "bg-emerald-100 text-emerald-700"
  defp status_class(_), do: "bg-stone-100 text-stone-600"

  defp po_trail(po, :items) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po),
      Navigation.page(:purchasing, :po_items, po)
    ]
  end

  defp po_trail(po, :add_item) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po),
      Navigation.page(:purchasing, :po_add_item, po)
    ]
  end

  defp po_trail(po, _) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po)
    ]
  end
end
