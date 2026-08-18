defmodule OpenSauceWeb.InventoryLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory
  alias OpenSauce.Types.Unit

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- header --%>
      <div style="padding:12px 16px 14px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;">
          Inventory
        </h1>
        <p style="font-size:13px;color:#9A9384;margin-top:3px;">
          Materials, stock levels, and pricing.
        </p>
      </div>

      <%!-- material list --%>
      <div style="padding:0 16px 0;" id="materials-list" phx-update="stream">
        <div
          :for={{dom_id, material} <- @streams.materials}
          id={dom_id}
          class="jcard"
          ontouchstart=""
          phx-click={JS.navigate(~p"/manage/inventory/#{material.sku}")}
          style="cursor:pointer;"
        >
          <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;">
            <div style="min-width:0;flex:1;">
              <p style="font-size:15.5px;font-weight:700;letter-spacing:-0.01em;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {material.name}
              </p>
              <div style="display:flex;align-items:center;gap:6px;margin-top:5px;">
                <span
                  class="catdot"
                  style={"background:#{type_color(material.material_type)};"}
                >
                </span>
                <span style="font-size:12px;font-weight:600;color:#6E675A;">
                  {type_label(material.material_type)}
                </span>
              </div>
            </div>
            <div style="text-align:right;flex-shrink:0;">
              <p style="font-size:14px;font-weight:700;color:#F4EFE2;">
                {format_amount(material.unit, material.current_stock)}
              </p>
              <p style="font-size:12px;color:#6E675A;margin-top:2px;">
                {format_money(@organisation.currency, material.price)}/{unit_abbr(material.unit)}
              </p>
            </div>
          </div>
        </div>
      </div>

      <p
        :if={@material_count == 0}
        style="font-size:13.5px;color:#6E675A;text-align:center;padding:40px 0 100px;"
      >
        No materials yet
      </p>

      <%!-- FAB --%>
      <button
        class="fab"
        ontouchstart=""
        aria-label="New material"
        phx-click={JS.patch(~p"/manage/inventory/new")}
      >
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none">
          <path d="M12 5v14M5 12h14" stroke="#0C1F15" stroke-width="2.4" stroke-linecap="round" />
        </svg>
      </button>

      <%!-- new material bottom sheet --%>
      <div
        :if={@live_action == :new}
        class="z-[60] fixed inset-0 flex flex-col justify-end"
        role="dialog"
        aria-label="New material"
      >
        <div
          class="bg-black/65 absolute inset-0"
          phx-click={JS.patch(~p"/manage/inventory")}
          aria-hidden="true"
        />
        <div
          class="bg-[#211E16] mobile-scroll relative w-full"
          style="border-radius:20px 20px 0 0;border-top:1.5px solid rgba(52,48,37,0.58);max-height:82vh;overflow-y:auto;padding-bottom:max(2rem,env(safe-area-inset-bottom));"
        >
          <div style="padding:12px 16px 10px;border-bottom:1px solid rgba(52,48,37,0.58);position:sticky;top:0;background:#211E16;z-index:1;">
            <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 12px;">
            </div>
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <span style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                New material
              </span>
              <.link patch={~p"/manage/inventory"}>
                <button
                  type="button"
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                >
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                    <path
                      d="M18 6L6 18M6 6l12 12"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                    />
                  </svg>
                </button>
              </.link>
            </div>
          </div>
          <div style="padding:20px 16px;">
            <.live_component
              module={OpenSauceWeb.InventoryLive.FormComponentMaterial}
              id={:new}
              current_member={@current_member}
              action={@live_action}
              material={nil}
              patch={~p"/manage/inventory"}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:material_count, 0) |> stream(:materials, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Inventory")
     |> assign(:main_bg, "bg-[#16140E]")
     |> load_materials()}
  end

  @impl true
  def handle_info({:saved, material}, socket) do
    member = socket.assigns.current_member
    material = Ash.load!(material, :current_stock, actor: member, tenant: member.organisation_id)

    {:noreply,
     socket
     |> update(:material_count, &(&1 + 1))
     |> stream_insert(:materials, material)}
  end

  defp load_materials(socket) do
    member = socket.assigns.current_member

    materials =
      Inventory.list_materials!(
        actor: member,
        tenant: member.organisation_id,
        load: [:current_stock]
      )

    socket
    |> assign(:material_count, length(materials))
    |> stream(:materials, materials, reset: true)
  end

  defp type_color(:plant), do: "#DB9258"
  defp type_color(_), do: "#54B57E"

  defp type_label(:plant), do: "Plant"
  defp type_label(_), do: "Supply"

  defp unit_abbr(unit), do: Unit.abbreviation(unit)
end
