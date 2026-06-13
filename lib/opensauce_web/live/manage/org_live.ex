defmodule OpenSauceWeb.OrgLive do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias AshPhoenix.Form
  alias OpenSauce.Accounts
  alias OpenSauce.Accounts.Roles

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member
    org = Accounts.get_organisation!(member.organisation_id, authorize?: false)
    members = Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)
    form = Form.for_update(org, :update_settings, authorize?: false, domain: Accounts, as: "org")

    {:ok,
     socket
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:page_title, "Organisation")
     |> assign(:org, org)
     |> assign(:members, members)
     |> assign(:form, to_form(form))
     |> assign(:show_invite_sheet, false)
     |> assign(:show_edit_sheet, false)
     |> assign(:editing_member, nil)
     |> assign(:invite_params, %{"email" => "", "role" => "staff", "display_title" => "", "labor_hourly_rate" => "0"})
     |> assign(:edit_params, %{})}
  end

  # -- Org form --

  @impl true
  def handle_event("validate_org", %{"org" => params}, socket) do
    form = Form.validate(socket.assigns.form.source, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save_org", %{"org" => params}, socket) do
    case Form.submit(socket.assigns.form.source, params: params) do
      {:ok, updated_org} ->
        form = Form.for_update(updated_org, :update_settings, authorize?: false, domain: Accounts, as: "org")

        {:noreply,
         socket
         |> assign(:org, updated_org)
         |> assign(:form, to_form(form))
         |> put_flash(:info, "Organisation updated.")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, "Could not save — check the fields below.")}
    end
  end

  # -- Invite sheet --

  @impl true
  def handle_event("open_invite", _, socket) do
    {:noreply, assign(socket, :show_invite_sheet, true)}
  end

  @impl true
  def handle_event("close_invite", _, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_sheet, false)
     |> assign(:invite_params, %{"email" => "", "role" => "staff", "display_title" => "", "labor_hourly_rate" => "0"})}
  end

  @impl true
  def handle_event("update_invite_field", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, :invite_params, Map.put(socket.assigns.invite_params, field, value))}
  end

  @impl true
  def handle_event("invite_member", _params, socket) do
    actor = socket.assigns.current_member
    p = socket.assigns.invite_params
    email = String.trim(p["email"] || "")

    if email == "" do
      {:noreply, put_flash(socket, :error, "Email is required.")}
    else
      user_result =
        case Accounts.get_user_by_email(email) do
          {:ok, user} -> {:ok, user}
          _ -> Accounts.create_user(%{email: email}, authorize?: false)
        end

      result =
        with {:ok, user} <- user_result do
          Accounts.create_organisation_member(
            %{
              user_id: user.id,
              organisation_id: actor.organisation_id,
              role: p["role"] || "staff",
              display_title: nilify(p["display_title"]),
              labor_hourly_rate: parse_rate(p["labor_hourly_rate"])
            },
            authorize?: false
          )
        end

      case result do
        {:ok, _} ->
          members = Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)

          {:noreply,
           socket
           |> assign(:members, members)
           |> assign(:show_invite_sheet, false)
           |> assign(:invite_params, %{"email" => "", "role" => "staff", "display_title" => "", "labor_hourly_rate" => "0"})
           |> put_flash(:info, "Member added.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not add member — they may already belong to this organisation.")}
      end
    end
  end

  # -- Edit member sheet --

  @impl true
  def handle_event("open_edit", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    edit_params = %{
      "first_name" => member.user.first_name || "",
      "last_name" => member.user.last_name || "",
      "email" => to_string(member.user.email),
      "role" => to_string(member.role),
      "display_title" => member.display_title || "",
      "labor_hourly_rate" => to_string(member.labor_hourly_rate)
    }

    {:noreply,
     socket
     |> assign(:show_edit_sheet, true)
     |> assign(:editing_member, member)
     |> assign(:edit_params, edit_params)}
  end

  @impl true
  def handle_event("close_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_sheet, false)
     |> assign(:editing_member, nil)
     |> assign(:edit_params, %{})}
  end

  @impl true
  def handle_event("update_edit_field", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, :edit_params, Map.put(socket.assigns.edit_params, field, value))}
  end

  @impl true
  def handle_event("save_member", _, socket) do
    actor = socket.assigns.current_member
    member = socket.assigns.editing_member
    p = socket.assigns.edit_params

    with {:ok, _} <-
           Accounts.update_organisation_member(
             member,
             %{
               role: p["role"],
               display_title: nilify(p["display_title"]),
               labor_hourly_rate: parse_rate(p["labor_hourly_rate"])
             },
             authorize?: false
           ),
         {:ok, _} <-
           Accounts.update_user(
             member.user,
             %{
               first_name: nilify(p["first_name"]),
               last_name: nilify(p["last_name"]),
               email: p["email"]
             },
             authorize?: false
           ) do
      members = Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)

      {:noreply,
       socket
       |> assign(:members, members)
       |> assign(:show_edit_sheet, false)
       |> assign(:editing_member, nil)
       |> assign(:edit_params, %{})
       |> put_flash(:info, "Member updated.")}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update member.")}
    end
  end

  # -- Suspend / activate --

  @impl true
  def handle_event("suspend_member", %{"id" => id}, socket) do
    actor = socket.assigns.current_member
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    case Accounts.suspend_organisation_member(member, authorize?: false) do
      {:ok, _} ->
        members = Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)
        {:noreply, socket |> assign(:members, members) |> put_flash(:info, "Access suspended.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not suspend member.")}
    end
  end

  @impl true
  def handle_event("activate_member", %{"id" => id}, socket) do
    actor = socket.assigns.current_member
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    case Accounts.activate_organisation_member(member, authorize?: false) do
      {:ok, _} ->
        members = Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)
        {:noreply, socket |> assign(:members, members) |> put_flash(:info, "Access restored.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not restore member.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;">

      <%!-- Invite sheet --%>
      <div
        :if={@show_invite_sheet}
        class="fixed inset-0 z-[60] flex items-end justify-center"
        role="dialog"
        aria-label="Add member"
      >
        <div class="absolute inset-0 bg-black/50" phx-click="close_invite" aria-hidden="true" />
        <div
          class="relative w-full max-w-lg bg-[#211E16] rounded-t-2xl px-5 pt-5 space-y-4"
          style="border-top:1.5px solid rgba(52,48,37,0.58);padding-bottom:max(2rem,env(safe-area-inset-bottom))"
        >
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:4px;">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
              Add member
            </p>
            <button type="button" phx-click="close_invite" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div style="display:flex;flex-direction:column;gap:12px;">
            <div>
              <label class="dark-label">Email address</label>
              <input
                class="dark-input"
                type="email"
                name="email"
                value={@invite_params["email"]}
                placeholder="member@example.com"
                phx-blur="update_invite_field"
                phx-value-field="email"
              />
            </div>
            <div>
              <label class="dark-label">Role</label>
              <select
                class="dark-select"
                name="role"
                phx-change="update_invite_field"
                phx-value-field="role"
              >
                <option :for={{label, val} <- role_options(@current_member)}
                  value={val}
                  selected={@invite_params["role"] == to_string(val)}
                >
                  {label}
                </option>
              </select>
            </div>
            <div>
              <label class="dark-label">Display title <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
              <input
                class="dark-input"
                type="text"
                name="display_title"
                value={@invite_params["display_title"]}
                placeholder="e.g. Lead Gardener"
                phx-blur="update_invite_field"
                phx-value-field="display_title"
              />
            </div>
            <div>
              <label class="dark-label">Hourly rate</label>
              <input
                class="dark-input"
                type="number"
                name="labor_hourly_rate"
                value={@invite_params["labor_hourly_rate"]}
                min="0"
                step="0.01"
                placeholder="0.00"
                phx-blur="update_invite_field"
                phx-value-field="labor_hourly_rate"
              />
            </div>
          </div>

          <div style="padding-top:4px;">
            <.glow_button type="button" phx-click="invite_member" valid={@invite_params["email"] != ""}>
              Add member
            </.glow_button>
          </div>
        </div>
      </div>

      <%!-- Edit member sheet --%>
      <div
        :if={@show_edit_sheet && @editing_member}
        class="fixed inset-0 z-[60] flex items-end justify-center"
        role="dialog"
        aria-label="Edit member"
      >
        <div class="absolute inset-0 bg-black/50" phx-click="close_edit" aria-hidden="true" />
        <div
          class="relative w-full max-w-lg bg-[#211E16] rounded-t-2xl"
          style="border-top:1.5px solid rgba(52,48,37,0.58);max-height:90dvh;display:flex;flex-direction:column;overflow:hidden;"
        >
          <%!-- Fixed header --%>
          <div style="padding:20px 20px 12px;flex-shrink:0;">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                Edit member
              </p>
              <button type="button" phx-click="close_edit" style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;">
                <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <%!-- Scrollable fields --%>
          <div style="overflow-y:auto;flex:1;min-height:0;padding:0 20px 12px;display:flex;flex-direction:column;gap:12px;">

            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div>
                <label class="dark-label">First name</label>
                <input
                  class="dark-input"
                  type="text"
                  name="first_name"
                  value={@edit_params["first_name"]}
                  placeholder="First name"
                  phx-blur="update_edit_field"
                  phx-value-field="first_name"
                />
              </div>
              <div>
                <label class="dark-label">Last name</label>
                <input
                  class="dark-input"
                  type="text"
                  name="last_name"
                  value={@edit_params["last_name"]}
                  placeholder="Last name"
                  phx-blur="update_edit_field"
                  phx-value-field="last_name"
                />
              </div>
            </div>

            <div>
              <label class="dark-label">Email</label>
              <input
                class="dark-input"
                type="email"
                name="email"
                value={@edit_params["email"]}
                placeholder="member@example.com"
                phx-blur="update_edit_field"
                phx-value-field="email"
              />
            </div>

            <div style="height:1px;background:rgba(52,48,37,0.58);margin:4px 0;"></div>

            <div>
              <label class="dark-label">Role</label>
              <select
                class="dark-select"
                name="role"
                phx-change="update_edit_field"
                phx-value-field="role"
              >
                <option :for={{label, val} <- role_options(@current_member)}
                  value={val}
                  selected={@edit_params["role"] == to_string(val)}
                >
                  {label}
                </option>
              </select>
            </div>

            <div>
              <label class="dark-label">Display title <span style="color:#6E675A;font-weight:400;">(optional)</span></label>
              <input
                class="dark-input"
                type="text"
                name="display_title"
                value={@edit_params["display_title"]}
                placeholder="e.g. Lead Gardener"
                phx-blur="update_edit_field"
                phx-value-field="display_title"
              />
            </div>

            <div>
              <label class="dark-label">Hourly rate</label>
              <input
                class="dark-input"
                type="number"
                name="labor_hourly_rate"
                value={@edit_params["labor_hourly_rate"]}
                min="0"
                step="0.01"
                placeholder="0.00"
                phx-blur="update_edit_field"
                phx-value-field="labor_hourly_rate"
              />
            </div>
          </div>

          <%!-- Fixed footer --%>
          <div style="padding:16px 20px;padding-bottom:max(16px,env(safe-area-inset-bottom));flex-shrink:0;">
            <.glow_button type="button" phx-click="save_member" valid={true}>
              Save changes
            </.glow_button>
          </div>
        </div>
      </div>

      <%!-- Page content --%>
      <div style="padding:16px;display:flex;flex-direction:column;gap:20px;padding-bottom:32px;">

        <%!-- Back --%>
        <div style="padding:4px 0;">
          <.link navigate={~p"/manage/account"} style="display:inline-flex;align-items:center;gap:6px;color:#6E675A;text-decoration:none;font-size:13px;font-weight:600;">
            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 12H5M12 19l-7-7 7-7"/>
            </svg>
            Account
          </.link>
        </div>

        <%!-- Org name header --%>
        <div style="font-family:'Bricolage Grotesque',sans-serif;font-size:24px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
          {@org.name}
        </div>

        <%!-- Org settings form --%>
        <.form for={@form} id="org-form" phx-change="validate_org" phx-submit="save_org">

          <%!-- General --%>
          <div>
            <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">General</p>
            <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
              <div>
                <label class="dark-label" for={@form[:name].id}>Organisation name</label>
                <input
                  class="dark-input"
                  type="text"
                  name={@form[:name].name}
                  id={@form[:name].id}
                  value={@form[:name].value || ""}
                />
                <span :for={msg <- @form[:name].errors} class="dark-field-error">{elem(msg, 0)}</span>
              </div>
              <div>
                <label class="dark-label" for={@form[:currency].id}>Currency</label>
                <select class="dark-select" name={@form[:currency].name} id={@form[:currency].id}>
                  <option :for={{label, val} <- [{"Canadian Dollar (CAD)", :CAD}, {"US Dollar (USD)", :USD}, {"Euro (EUR)", :EUR}]}
                    value={val}
                    selected={to_string(@form[:currency].value) == to_string(val)}
                  >
                    {label}
                  </option>
                </select>
              </div>
            </div>
          </div>

          <%!-- Pricing --%>
          <div style="margin-top:20px;">
            <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">Pricing</p>
            <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
              <div>
                <label class="dark-label" for={@form[:tax_mode].id}>Tax mode</label>
                <select class="dark-select" name={@form[:tax_mode].name} id={@form[:tax_mode].id}>
                  <option :for={{label, val} <- [{"Exclusive — add tax on top", :exclusive}, {"Inclusive — price includes tax", :inclusive}]}
                    value={val}
                    selected={to_string(@form[:tax_mode].value) == to_string(val)}
                  >
                    {label}
                  </option>
                </select>
              </div>
              <div>
                <label class="dark-label" for={@form[:labor_overhead_percent].id}>Labour overhead %</label>
                <input
                  class="dark-input"
                  type="number"
                  step="0.001"
                  min="0"
                  name={@form[:labor_overhead_percent].name}
                  id={@form[:labor_overhead_percent].id}
                  value={@form[:labor_overhead_percent].value || "0"}
                  placeholder="0.15"
                />
                <span :for={msg <- @form[:labor_overhead_percent].errors} class="dark-field-error">{elem(msg, 0)}</span>
              </div>
              <div>
                <label class="dark-label" for={@form[:mileage_cost_per_km].id}>Mileage cost / km</label>
                <input
                  class="dark-input"
                  type="number"
                  step="0.001"
                  min="0"
                  name={@form[:mileage_cost_per_km].name}
                  id={@form[:mileage_cost_per_km].id}
                  value={@form[:mileage_cost_per_km].value || "0"}
                  placeholder="0.61"
                />
                <span :for={msg <- @form[:mileage_cost_per_km].errors} class="dark-field-error">{elem(msg, 0)}</span>
              </div>
            </div>
          </div>

          <%!-- Email --%>
          <div style="margin-top:20px;">
            <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">Email</p>
            <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
              <div>
                <label class="dark-label" for={@form[:email_from_name].id}>From name</label>
                <input
                  class="dark-input"
                  type="text"
                  name={@form[:email_from_name].name}
                  id={@form[:email_from_name].id}
                  value={@form[:email_from_name].value || ""}
                  placeholder="Green Thumb Co"
                />
              </div>
              <div>
                <label class="dark-label" for={@form[:email_from_address].id}>From address</label>
                <input
                  class="dark-input"
                  type="email"
                  name={@form[:email_from_address].name}
                  id={@form[:email_from_address].id}
                  value={@form[:email_from_address].value || ""}
                  placeholder="hello@example.com"
                />
              </div>
            </div>
          </div>

          <div style="margin-top:16px;">
            <.glow_button type="submit" valid={true}>Save organisation</.glow_button>
          </div>
        </.form>

        <%!-- Staff --%>
        <div style="margin-top:4px;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Staff
            </p>
            <button
              :if={Roles.can_create_staff?(@current_member)}
              type="button"
              phx-click="open_invite"
              ontouchstart=""
              style="display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;"
            >
              <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 5v14M5 12h14"/>
              </svg>
              Add
            </button>
          </div>

          <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);overflow:hidden;">
            <div
              :for={{m, idx} <- Enum.with_index(@members)}
              style={"padding:12px 14px;display:flex;align-items:center;gap:12px;#{if idx > 0, do: "border-top:1px solid rgba(52,48,37,0.58);"}"}
            >
              <%!-- Avatar --%>
              <div style={"width:36px;height:36px;border-radius:10px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:14px;letter-spacing:-0.01em;color:#fff;opacity:#{if m.status == :suspended, do: "0.45", else: "1"};#{member_gradient(m.role)}"}>
                {member_initial(m)}
              </div>

              <%!-- Info --%>
              <div style="flex:1;min-width:0;">
                <div style={"font-size:13.5px;font-weight:600;line-height:1.3;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;#{if m.status == :suspended, do: "color:#6E675A;", else: "color:#F4EFE2;"}"}>
                  {member_display_name(m)}
                </div>
                <div style="margin-top:3px;display:flex;align-items:center;gap:6px;flex-wrap:wrap;">
                  <span style={"font-size:10.5px;font-weight:700;letter-spacing:0.03em;padding:2px 7px;border-radius:999px;#{role_pill_style(m.role)}"}>
                    {role_label(m.role)}
                  </span>
                  <span :if={m.status == :suspended} style="font-size:10.5px;font-weight:700;letter-spacing:0.03em;padding:2px 7px;border-radius:999px;background:rgba(232,126,126,0.14);color:#E87E7E;">
                    Suspended
                  </span>
                </div>
              </div>

              <%!-- Actions (not for self) --%>
              <div :if={m.id != @current_member.id && Roles.can_manage_members?(@current_member)} style="display:flex;align-items:center;gap:6px;flex-shrink:0;">
                <button
                  type="button"
                  phx-click="open_edit"
                  phx-value-id={m.id}
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Edit"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                  </svg>
                </button>
                <button
                  :if={m.status == :active}
                  type="button"
                  phx-click="suspend_member"
                  phx-value-id={m.id}
                  ontouchstart=""
                  style="color:#E87E7E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Suspend"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/>
                  </svg>
                </button>
                <button
                  :if={m.status == :suspended}
                  type="button"
                  phx-click="activate_member"
                  phx-value-id={m.id}
                  ontouchstart=""
                  style="color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Restore access"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp role_options(actor) do
    roles = if Roles.can_promote_to_owner?(actor), do: [:owner, :manager, :staff], else: [:manager, :staff]
    Enum.map(roles, &{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp member_display_name(%{user: %{first_name: f, last_name: l, email: email}}) do
    cond do
      f && l -> "#{f} #{l}"
      f -> f
      true -> to_string(email)
    end
  end

  defp member_display_name(%{user: %{email: email}}), do: to_string(email)
  defp member_display_name(_), do: "—"

  defp member_initial(%{user: %{first_name: f, email: email}}) when is_binary(f) and f != "" do
    f |> String.first() |> String.upcase()
  end

  defp member_initial(%{user: %{email: email}}) do
    email |> to_string() |> String.split("@") |> hd() |> String.first() |> String.upcase()
  end

  defp member_initial(_), do: "?"

  defp member_gradient(:owner), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp member_gradient(:manager), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp member_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"

  defp role_pill_style(:owner), do: "background:rgba(219,146,88,0.16);color:#DB9258;"
  defp role_pill_style(:manager), do: "background:rgba(219,146,88,0.16);color:#DB9258;"
  defp role_pill_style(_), do: "background:rgba(84,181,126,0.14);color:#54B57E;"

  defp role_label(:owner), do: "Owner"
  defp role_label(:manager), do: "Manager"
  defp role_label(_), do: "Field crew"

  defp nilify(""), do: nil
  defp nilify(s), do: s

  defp parse_rate(nil), do: 0
  defp parse_rate(""), do: 0

  defp parse_rate(s) do
    case Decimal.parse(to_string(s)) do
      {d, ""} -> d
      _ -> 0
    end
  end
end
