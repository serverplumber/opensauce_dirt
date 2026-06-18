defmodule OpenSauceWeb.InventoryLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;padding-bottom:130px;">
      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={~p"/manage/inventory"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M19 12H5M12 19l-7-7 7-7"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </button>
        </.link>
        <.link patch={~p"/manage/inventory/#{@material.sku}/edit"}>
          <button
            type="button"
            ontouchstart=""
            style="font-size:13.5px;font-weight:700;color:#6E675A;background:none;border:none;cursor:pointer;padding:4px;"
          >
            Edit
          </button>
        </.link>
      </div>

      <%!-- title + type --%>
      <div style="padding:14px 16px 20px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;margin:0 0 6px;">
          {@material.name}
        </h1>
        <div style="display:flex;align-items:center;gap:6px;">
          <span
            class="catdot"
            style={"background:#{type_color(@material.material_type)};"}
          >
          </span>
          <span style="font-size:12.5px;font-weight:600;color:#9A9384;">
            {type_label(@material.material_type)}
          </span>
          <span style="color:#6E675A;font-size:12px;">·</span>
          <span style="font-size:12.5px;font-weight:600;color:#9A9384;font-family:'Bricolage Grotesque',sans-serif;">
            {@material.sku}
          </span>
        </div>
      </div>

      <%!-- tab bar --%>
      <div style="padding:0 16px 14px;">
        <div style="display:flex;gap:4px;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:13px;padding:4px;">
          <.link patch={~p"/manage/inventory/#{@material.sku}/details"} style="flex:1;text-decoration:none;">
            <button
              type="button"
              ontouchstart=""
              class={["seg-tab", details_active?(@live_action) && "seg-tab--on"]}
              style="width:100%;"
            >
              Details
            </button>
          </.link>
          <.link patch={~p"/manage/inventory/#{@material.sku}/stock"} style="flex:1;text-decoration:none;">
            <button
              type="button"
              ontouchstart=""
              class={["seg-tab", stock_active?(@live_action) && "seg-tab--on"]}
              style="width:100%;"
            >
              Stock
            </button>
          </.link>
        </div>
      </div>

      <%!-- details tab --%>
      <div :if={details_active?(@live_action)} style="padding:0 16px;">
        <%!-- key stats row --%>
        <div style="display:flex;gap:10px;margin-bottom:14px;">
          <.stat_tile label="Current" value={format_amount(@material.unit, @material.current_stock)} accent />
          <.stat_tile label={"Price/#{unit_abbr(@material.unit)}"} value={format_money(@organisation.currency, @material.price)} />
          <.stat_tile label="Min" value={format_amount(@material.unit, @material.minimum_stock)} />
          <.stat_tile label="Max" value={format_amount(@material.unit, @material.maximum_stock)} />
        </div>

        <%!-- open purchase orders --%>
        <div :if={@open_po_items != []} style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:16px;overflow:hidden;margin-bottom:14px;">
          <div style="padding:12px 16px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Open purchase orders
            </span>
          </div>
          <div
            :for={poi <- @open_po_items}
            style="padding:12px 16px;border-bottom:1px solid rgba(52,48,37,0.3);display:flex;align-items:center;justify-content:space-between;"
          >
            <div>
              <p style="font-size:13.5px;font-weight:600;color:#F4EFE2;">
                {poi.purchase_order.supplier.name}
              </p>
              <p style="font-size:12px;color:#6E675A;margin-top:2px;font-family:'Bricolage Grotesque',sans-serif;">
                {poi.purchase_order.reference}
              </p>
            </div>
            <div style="text-align:right;">
              <p style="font-size:13.5px;font-weight:700;color:#54B57E;">
                {format_amount(@material.unit, poi.quantity)}
              </p>
              <p style="font-size:11px;color:#6E675A;margin-top:2px;text-transform:uppercase;letter-spacing:0.04em;">
                {poi.purchase_order.status}
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- stock tab --%>
      <div :if={stock_active?(@live_action)} style="padding:0 16px;">
        <p
          :if={@material.movements == []}
          style="font-size:13.5px;color:#6E675A;text-align:center;padding:32px 0;"
        >
          No movements yet
        </p>

        <div
          :if={@material.movements != []}
          style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:16px;overflow:hidden;"
        >
          <div
            :for={entry <- Enum.sort_by(@material.movements, & &1.occurred_at, {:desc, DateTime})}
            style="padding:12px 16px;border-bottom:1px solid rgba(52,48,37,0.3);display:flex;align-items:center;justify-content:space-between;gap:10px;"
          >
            <div style="min-width:0;flex:1;">
              <p style="font-size:12px;color:#6E675A;">
                {format_time(entry.occurred_at, format: "%-d %b %H:%M", timezone: @time_zone)}
              </p>
              <p :if={entry.reason} style="font-size:13px;color:#9A9384;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {entry.reason}
              </p>
            </div>
            <span style={"font-size:14px;font-weight:700;flex-shrink:0;#{movement_color(entry.quantity)}"}>
              {movement_label(@material.unit, entry.quantity)}
            </span>
          </div>
        </div>
      </div>

      <%!-- sticky CTA: adjust stock --%>
      <div style="position:fixed;bottom:74px;left:0;right:0;padding:10px 16px;background:#16140E;border-top:1px solid rgba(52,48,37,0.58);">
        <.link patch={~p"/manage/inventory/#{@material.sku}/adjust"} style="display:block;">
          <.glow_button valid={true}>Adjust stock</.glow_button>
        </.link>
      </div>

      <%!-- edit material modal --%>
      <.modal
        :if={@live_action == :edit}
        id="material-edit-modal"
        title="Edit material"
        show
        on_cancel={JS.patch(~p"/manage/inventory/#{@material.sku}/details")}
      >
        <.live_component
          module={OpenSauceWeb.InventoryLive.FormComponentMaterial}
          id={@material.id}
          current_member={@current_member}
          action={@live_action}
          material={@material}
          patch={~p"/manage/inventory/#{@material.sku}/details"}
        />
      </.modal>

      <%!-- adjust stock modal --%>
      <.modal
        :if={@live_action == :adjust}
        id="material-adjust-modal"
        title={"Adjust — #{@material.name}"}
        show
        on_cancel={JS.patch(~p"/manage/inventory/#{@material.sku}/stock")}
      >
        <.live_component
          module={OpenSauceWeb.InventoryLive.FormComponentMovement}
          id={@material.id}
          material={@material}
          current_member={@current_member}
          patch={~p"/manage/inventory/#{@material.sku}/stock"}
        />
      </.modal>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :accent, :boolean, default: false

  defp stat_tile(assigns) do
    ~H"""
    <div style="flex:1;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:12px;padding:10px 12px;min-width:0;">
      <p style="font-size:10.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:4px;">
        {@label}
      </p>
      <p style={"font-size:15px;font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;#{if @accent, do: "color:#54B57E;", else: "color:#F4EFE2;"}"}>
        {@value}
      </p>
    </div>
    """
  end

  @impl true
  def handle_params(%{"sku" => sku}, _, socket) do
    member = socket.assigns.current_member

    material =
      Inventory.get_material_by_sku!(sku,
        load: [:current_stock, :movements],
        actor: member,
        tenant: member.organisation_id
      )

    open_po_items =
      Inventory.list_open_po_items_for_material!(
        %{material_id: material.id},
        actor: member,
        tenant: member.organisation_id
      )

    {:noreply,
     socket
     |> assign(:page_title, material.name)
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:material, material)
     |> assign(:open_po_items, open_po_items)}
  end

  @impl true
  def handle_info({:saved, %Inventory.Movement{}}, socket) do
    {:noreply, reload_material(socket)}
  end

  @impl true
  def handle_info({:saved, %Inventory.Material{}}, socket) do
    {:noreply, reload_material(socket)}
  end

  defp reload_material(socket) do
    member = socket.assigns.current_member
    sku = socket.assigns.material.sku

    material =
      Inventory.get_material_by_sku!(sku,
        load: [:current_stock, :movements],
        actor: member,
        tenant: member.organisation_id
      )

    assign(socket, :material, material)
  end

  defp details_active?(live_action), do: live_action in [:show, :details, :edit]
  defp stock_active?(live_action), do: live_action in [:stock, :adjust]

  defp type_color(:plant), do: "#DB9258"
  defp type_color(_), do: "#54B57E"

  defp type_label(:plant), do: "Plant"
  defp type_label(_), do: "Supply"

  defp unit_abbr(:gram), do: "g"
  defp unit_abbr(:milliliter), do: "mL"
  defp unit_abbr(:piece), do: "pcs"
  defp unit_abbr(_), do: ""

  defp movement_color(qty) do
    case Decimal.compare(qty, Decimal.new(0)) do
      :gt -> "color:#54B57E;"
      :lt -> "color:#E87E7E;"
      _ -> "color:#9A9384;"
    end
  end

  defp movement_label(unit, qty) do
    abs_qty = Decimal.abs(qty)

    case Decimal.compare(qty, Decimal.new(0)) do
      :gt -> "+#{format_amount(unit, abs_qty)}"
      :lt -> "-#{format_amount(unit, abs_qty)}"
      _ -> format_amount(unit, abs_qty)
    end
  end
end
