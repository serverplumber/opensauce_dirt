defmodule OpenSauceWeb.PurchasingLive.Suppliers do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- header --%>
      <div style="padding:12px 16px 14px;display:flex;align-items:center;gap:10px;">
        <.link navigate={~p"/manage/purchasing"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </button>
        </.link>
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;flex:1;">
          Suppliers
        </h1>
      </div>

      <%!-- supplier list --%>
      <div style="padding:0 16px 100px;display:flex;flex-direction:column;gap:10px;">
        <div
          :for={s <- @suppliers}
          style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px;"
        >
          <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:8px;">
            <div style="min-width:0;flex:1;">
              <p style="font-size:15.5px;font-weight:700;letter-spacing:-0.01em;color:#F4EFE2;">{s.name}</p>
              <p :if={s.contact_name} style="font-size:13px;color:#9A9384;margin-top:3px;">{s.contact_name}</p>
              <div style="display:flex;flex-direction:column;gap:2px;margin-top:4px;">
                <p :if={s.contact_email} style="font-size:12px;color:#6E675A;">{s.contact_email}</p>
                <p :if={s.contact_phone} style="font-size:12px;color:#6E675A;">{s.contact_phone}</p>
              </div>
              <div :if={s.addresses != []} style="margin-top:8px;display:flex;flex-direction:column;gap:3px;">
                <p :for={addr <- s.addresses} style="font-size:12px;color:#6E675A;">
                  ↳ {addr_short(addr)}
                </p>
              </div>
            </div>
          </div>
          <div style="display:flex;gap:8px;margin-top:12px;border-top:1px solid rgba(52,48,37,0.58);padding-top:10px;">
            <.link navigate={~p"/manage/purchasing/suppliers/#{s.id}/import"} style="flex:1;">
              <button
                type="button"
                ontouchstart=""
                style="width:100%;background:rgba(52,48,37,0.5);border:1px solid rgba(52,48,37,0.58);border-radius:10px;padding:8px;font-size:13px;font-weight:600;color:#9A9384;cursor:pointer;"
              >
                Import catalog
              </button>
            </.link>
            <.link patch={~p"/manage/purchasing/suppliers/#{s.id}/edit"} style="flex-shrink:0;">
              <button
                type="button"
                ontouchstart=""
                style="background:rgba(52,48,37,0.5);border:1px solid rgba(52,48,37,0.58);border-radius:10px;padding:8px 14px;font-size:13px;font-weight:600;color:#F4EFE2;cursor:pointer;"
              >
                Edit
              </button>
            </.link>
          </div>
        </div>

        <p
          :if={@suppliers == []}
          style="font-size:13.5px;color:#6E675A;text-align:center;padding:40px 0;"
        >
          No suppliers yet
        </p>
      </div>

      <%!-- FAB --%>
      <button
        class="fab"
        ontouchstart=""
        aria-label="New supplier"
        phx-click={JS.patch(~p"/manage/purchasing/suppliers/new")}
      >
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none">
          <path d="M12 5v14M5 12h14" stroke="#0C1F15" stroke-width="2.4" stroke-linecap="round" />
        </svg>
      </button>

      <%!-- new / edit supplier bottom sheet --%>
      <div
        :if={@live_action in [:new, :edit]}
        class="fixed inset-0 z-[60] flex flex-col justify-end"
        role="dialog"
        aria-label={if @live_action == :new, do: "New supplier", else: "Edit supplier"}
      >
        <div
          class="absolute inset-0 bg-black/65"
          phx-click={JS.patch(~p"/manage/purchasing/suppliers")}
          aria-hidden="true"
        />
        <div
          class="relative w-full bg-[#211E16] mobile-scroll"
          style="border-radius:20px 20px 0 0;border-top:1.5px solid rgba(52,48,37,0.58);max-height:88vh;overflow-y:auto;padding-bottom:max(2rem,env(safe-area-inset-bottom));"
        >
          <div style="padding:12px 16px 10px;border-bottom:1px solid rgba(52,48,37,0.58);position:sticky;top:0;background:#211E16;z-index:1;">
            <div style="width:36px;height:4px;border-radius:2px;background:rgba(52,48,37,0.8);margin:0 auto 12px;" />
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <span style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                {if @live_action == :new, do: "New supplier", else: "Edit supplier"}
              </span>
              <.link patch={~p"/manage/purchasing/suppliers"}>
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
              module={OpenSauceWeb.PurchasingLive.SupplierFormComponent}
              id={(@supplier && @supplier.id) || :new}
              current_member={@current_member}
              supplier={@supplier}
              patch={~p"/manage/purchasing/suppliers"}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    members = socket.assigns.current_member

    suppliers =
      Inventory.list_suppliers!(actor: members, tenant: members.organisation_id, load: [:addresses])

    {:ok,
     socket
     |> assign(:suppliers, suppliers)
     |> assign(:supplier, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:page_title, "Suppliers")
      |> assign(:main_bg, "bg-[#16140E]")

    socket =
      case socket.assigns.live_action do
        :edit ->
          member = socket.assigns.current_member

          sup =
            Inventory.get_supplier_by_id!(params["id"],
              actor: member,
              tenant: member.organisation_id,
              load: [:addresses]
            )

          assign(socket, :supplier, sup)

        _ ->
          assign(socket, :supplier, nil)
      end

    {:noreply,
     Navigation.assign(socket, :purchasing, [
       Navigation.root(:purchasing),
       Navigation.page(:purchasing, :suppliers)
     ])}
  end

  @impl true
  def handle_info({:supplier_saved, _sup}, socket) do
    member = socket.assigns.current_member

    {:noreply,
     socket
     |> assign(:suppliers, Inventory.list_suppliers!(actor: member, tenant: member.organisation_id, load: [:addresses]))
     |> push_patch(to: ~p"/manage/purchasing/suppliers")}
  end

  defp addr_short(%{name: name, street: street, city: city})
       when not is_nil(name) and name != "" do
    location = [street, city] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(", ")
    if location != "", do: "#{name} · #{location}", else: name
  end

  defp addr_short(%{street: street, city: city}) do
    [street, city] |> Enum.reject(&(is_nil(&1) or &1 == "")) |> Enum.join(", ")
  end
end
