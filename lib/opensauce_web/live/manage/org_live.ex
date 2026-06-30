defmodule OpenSauceWeb.OrgLive do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias AshPhoenix.Form
  alias OpenSauce.Accounts
  alias OpenSauce.Accounts.Roles

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member
    org = Accounts.get_organisation!(member.organisation_id, authorize?: false, load: [:address])
    members = Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)
    form = Form.for_update(org, :update_settings, authorize?: false, domain: Accounts, as: "org")

    tax_rates = Accounts.list_tax_rates!(actor: member, tenant: member.organisation_id)

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
     |> assign(:invite_params, %{
       "email" => "",
       "role" => "staff",
       "display_title" => "",
       "labor_hourly_rate" => "0"
     })
     |> assign(:tax_rates, tax_rates)
     |> assign(:show_tax_sheet, false)
     |> assign(:editing_tax_rate, nil)
     |> assign(:tax_params, default_tax_params())
     |> assign(:sign_off_items, org.estimate_sign_off_items || [])
     |> assign(:show_sign_off_sheet, false)
     |> assign(:editing_sign_off_index, nil)
     |> assign(:sign_off_params, %{"label" => "", "body" => ""})
     |> allow_upload(:logo_colour,
       accept: ~w(image/png),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> allow_upload(:logo_greyscale,
       accept: ~w(image/png),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign(:logo_colour_warning, nil)
     |> assign(:logo_greyscale_warning, nil)}
  end

  # -- Org form --

  @impl true
  def handle_event("validate_org", params, socket) do
    org_params = Map.get(params, "org", %{})
    form = Form.validate(socket.assigns.form.source, org_params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save_org", params, socket) do
    org_params = Map.get(params, "org", %{})
    address_params = params |> Map.get("address", %{}) |> nilify_map_values()
    member = socket.assigns.current_member

    case Form.submit(socket.assigns.form.source, params: org_params) do
      {:ok, updated_org} ->
        upsert_org_address(socket.assigns.org, address_params)

        updated_org =
          Accounts.get_organisation!(updated_org.id, authorize?: false, load: [:address])

        form =
          Form.for_update(updated_org, :update_settings,
            authorize?: false,
            domain: Accounts,
            as: "org"
          )

        {:noreply,
         socket
         |> assign(:org, updated_org)
         |> assign(:form, to_form(form))
         |> put_flash(:info, "Organisation updated.")}

      {:error, %Form{} = form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, "Could not save — check the fields below.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save.")}
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
     |> assign(:invite_params, %{
       "email" => "",
       "role" => "staff",
       "display_title" => "",
       "labor_hourly_rate" => "0"
     })}
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
          members =
            Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)

          {:noreply,
           socket
           |> assign(:members, members)
           |> assign(:show_invite_sheet, false)
           |> assign(:invite_params, %{
             "email" => "",
             "role" => "staff",
             "display_title" => "",
             "labor_hourly_rate" => "0"
           })
           |> put_flash(:info, "Member added.")}

        {:error, _} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Could not add member — they may already belong to this organisation."
           )}
      end
    end
  end

  # -- Edit member sheet --

  @impl true
  def handle_event("open_edit", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))
    {:noreply, socket |> assign(:show_edit_sheet, true) |> assign(:editing_member, member)}
  end

  @impl true
  def handle_event("close_edit", _, socket) do
    {:noreply, socket |> assign(:show_edit_sheet, false) |> assign(:editing_member, nil)}
  end

  @impl true
  def handle_event("save_member", %{"member" => p}, socket) do
    actor = socket.assigns.current_member
    member = socket.assigns.editing_member

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
        members =
          Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)

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
        members =
          Accounts.list_members_for_organisation!(actor.organisation_id, authorize?: false)

        {:noreply, socket |> assign(:members, members) |> put_flash(:info, "Access restored.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not restore member.")}
    end
  end

  # -- Tax rate sheet --

  @impl true
  def handle_event("open_tax_form", %{"id" => id}, socket) do
    rate = Enum.find(socket.assigns.tax_rates, &(&1.id == id))

    params = %{
      "name" => rate.name,
      "rate" => Decimal.to_string(rate.rate),
      "registration_number" => rate.registration_number || "",
      "is_compound" => rate.is_compound
    }

    {:noreply,
     socket
     |> assign(:show_tax_sheet, true)
     |> assign(:editing_tax_rate, rate)
     |> assign(:tax_params, params)}
  end

  @impl true
  def handle_event("open_tax_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_tax_sheet, true)
     |> assign(:editing_tax_rate, nil)
     |> assign(:tax_params, default_tax_params())}
  end

  @impl true
  def handle_event("close_tax_form", _, socket) do
    {:noreply,
     socket
     |> assign(:show_tax_sheet, false)
     |> assign(:editing_tax_rate, nil)
     |> assign(:tax_params, default_tax_params())}
  end

  @impl true
  def handle_event("update_tax_field", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, :tax_params, Map.put(socket.assigns.tax_params, field, value))}
  end

  @impl true
  def handle_event("toggle_tax_compound", _, socket) do
    params = Map.update!(socket.assigns.tax_params, "is_compound", &(!&1))
    {:noreply, assign(socket, :tax_params, params)}
  end

  @impl true
  def handle_event("save_tax_rate", _, socket) do
    member = socket.assigns.current_member
    p = socket.assigns.tax_params

    attrs = %{
      name: p["name"],
      rate: parse_rate(p["rate"]),
      is_compound: p["is_compound"],
      registration_number: nilify(p["registration_number"])
    }

    result =
      case socket.assigns.editing_tax_rate do
        nil ->
          position = length(socket.assigns.tax_rates)

          Accounts.create_tax_rate(Map.put(attrs, :position, position),
            actor: member,
            tenant: member.organisation_id
          )

        rate ->
          Accounts.update_tax_rate(rate, attrs, actor: member, tenant: member.organisation_id)
      end

    case result do
      {:ok, _} ->
        tax_rates = Accounts.list_tax_rates!(actor: member, tenant: member.organisation_id)

        {:noreply,
         socket
         |> assign(:tax_rates, tax_rates)
         |> assign(:show_tax_sheet, false)
         |> assign(:editing_tax_rate, nil)
         |> assign(:tax_params, default_tax_params())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save tax rate.")}
    end
  end

  @impl true
  def handle_event("delete_tax_rate", %{"id" => id}, socket) do
    member = socket.assigns.current_member
    rate = Enum.find(socket.assigns.tax_rates, &(&1.id == id))

    case Accounts.delete_tax_rate(rate, actor: member, tenant: member.organisation_id) do
      :ok ->
        tax_rates = Accounts.list_tax_rates!(actor: member, tenant: member.organisation_id)
        {:noreply, assign(socket, :tax_rates, tax_rates)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete tax rate.")}
    end
  end

  @impl true
  def handle_event("move_tax_up", %{"id" => id}, socket) do
    {:noreply, reorder_tax(socket, id, :up)}
  end

  @impl true
  def handle_event("move_tax_down", %{"id" => id}, socket) do
    {:noreply, reorder_tax(socket, id, :down)}
  end

  defp reorder_tax(socket, id, direction) do
    member = socket.assigns.current_member
    rates = socket.assigns.tax_rates
    idx = Enum.find_index(rates, &(&1.id == id))

    swap_idx =
      case direction do
        :up -> if idx && idx > 0, do: idx - 1
        :down -> if idx && idx < length(rates) - 1, do: idx + 1
      end

    if is_nil(swap_idx) do
      socket
    else
      reordered = list_swap(rates, idx, swap_idx)

      reordered
      |> Enum.with_index()
      |> Enum.each(fn {rate, i} ->
        if rate.position != i do
          Accounts.update_tax_rate(rate, %{position: i},
            actor: member,
            tenant: member.organisation_id
          )
        end
      end)

      saved_rates =
        reordered |> Enum.with_index() |> Enum.map(fn {r, i} -> %{r | position: i} end)

      assign(socket, :tax_rates, saved_rates)
    end
  end

  defp list_swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  defp default_tax_params, do: %{"name" => "", "rate" => "0", "registration_number" => "", "is_compound" => false}

  # -- Sign-off items --

  @impl true
  def handle_event("open_sign_off_form", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    item = Enum.at(socket.assigns.sign_off_items, idx)

    params = %{
      "label" => item["label"] || "",
      "body" => item["body"] || ""
    }

    {:noreply,
     socket
     |> assign(:show_sign_off_sheet, true)
     |> assign(:editing_sign_off_index, idx)
     |> assign(:sign_off_params, params)}
  end

  @impl true
  def handle_event("open_sign_off_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_sign_off_sheet, true)
     |> assign(:editing_sign_off_index, nil)
     |> assign(:sign_off_params, %{"label" => "", "body" => ""})}
  end

  @impl true
  def handle_event("close_sign_off_form", _, socket) do
    {:noreply,
     socket
     |> assign(:show_sign_off_sheet, false)
     |> assign(:editing_sign_off_index, nil)
     |> assign(:sign_off_params, %{"label" => "", "body" => ""})}
  end

  @impl true
  def handle_event("update_sign_off_field", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, :sign_off_params, Map.put(socket.assigns.sign_off_params, field, value))}
  end

  @impl true
  def handle_event("save_sign_off_item", _, socket) do
    p = socket.assigns.sign_off_params
    item = %{"label" => String.trim(p["label"] || ""), "body" => nilify(p["body"])}

    items =
      case socket.assigns.editing_sign_off_index do
        nil -> socket.assigns.sign_off_items ++ [item]
        idx -> List.replace_at(socket.assigns.sign_off_items, idx, item)
      end

    save_sign_off_items(socket, items)
  end

  @impl true
  def handle_event("remove_sign_off_item", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    items = List.delete_at(socket.assigns.sign_off_items, idx)
    save_sign_off_items(socket, items)
  end

  defp save_sign_off_items(socket, items) do
    case Ash.update(socket.assigns.org, %{estimate_sign_off_items: items},
           action: :update_settings,
           authorize?: false
         ) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:org, updated_org)
         |> assign(:sign_off_items, items)
         |> assign(:show_sign_off_sheet, false)
         |> assign(:editing_sign_off_index, nil)
         |> assign(:sign_off_params, %{"label" => "", "body" => ""})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save sign-off items.")}
    end
  end

  # -- Logos --

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref, "name" => name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(name), ref)}
  end

  @impl true
  def handle_progress(:logo_colour, entry, socket) do
    if entry.done?,
      do:
        consume_and_save_logo(
          socket,
          :logo_colour,
          "logo_colour.png",
          :logo_colour_key,
          "Colour logo",
          :logo_colour_warning
        ),
      else: {:noreply, socket}
  end

  @impl true
  def handle_progress(:logo_greyscale, entry, socket) do
    if entry.done?,
      do:
        consume_and_save_logo(
          socket,
          :logo_greyscale,
          "logo_greyscale.png",
          :logo_greyscale_key,
          "Greyscale logo",
          :logo_greyscale_warning
        ),
      else: {:noreply, socket}
  end

  defp consume_and_save_logo(socket, upload_name, storage_filename, attr, label, warning_assign) do
    org = socket.assigns.org

    {results, socket} =
      consume_uploaded_entries(socket, upload_name, fn %{path: path}, _entry ->
        {:ok, process_logo_file(path, org, storage_filename, label)}
      end)

    case results do
      [] ->
        {:noreply, socket}

      [{:error, msg}] ->
        {:noreply, put_flash(socket, :error, msg)}

      [result] ->
        {key, warning} =
          case result do
            {:ok, k} -> {k, nil}
            {:warn, k, w} -> {k, w}
          end

        old_key = Map.get(org, attr)

        case Ash.update(org, %{attr => key}, action: :update_logos, authorize?: false) do
          {:ok, updated_org} ->
            if old_key, do: OpenSauce.Storage.delete(old_key)
            {:noreply, socket |> assign(:org, updated_org) |> assign(warning_assign, warning)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not save logo.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;">
      <%!-- Invite sheet --%>
      <div
        :if={@show_invite_sheet}
        class="z-[60] fixed inset-0 flex items-end justify-center"
        role="dialog"
        aria-label="Add member"
      >
        <div class="bg-black/50 absolute inset-0" phx-click="close_invite" aria-hidden="true" />
        <div
          class="bg-[#211E16] relative w-full max-w-lg space-y-4 rounded-t-2xl px-5 pt-5"
          style="border-top:1.5px solid rgba(52,48,37,0.58);padding-bottom:max(2rem,env(safe-area-inset-bottom))"
        >
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:4px;">
            <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
              Add member
            </p>
            <button
              type="button"
              phx-click="close_invite"
              style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
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
                <option
                  :for={{label, val} <- role_options(@current_member)}
                  value={val}
                  selected={@invite_params["role"] == to_string(val)}
                >
                  {label}
                </option>
              </select>
            </div>
            <div>
              <label class="dark-label">
                Display title <span style="color:#6E675A;font-weight:400;">(optional)</span>
              </label>
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
            <.glow_button
              type="button"
              phx-click="invite_member"
              valid={@invite_params["email"] != ""}
            >
              Add member
            </.glow_button>
          </div>
        </div>
      </div>

      <%!-- Edit member sheet --%>
      <div
        :if={@show_edit_sheet && @editing_member}
        class="z-[60] fixed inset-0 flex items-end justify-center"
        role="dialog"
        aria-label="Edit member"
      >
        <div class="bg-black/50 absolute inset-0" phx-click="close_edit" aria-hidden="true" />
        <div
          class="bg-[#211E16] relative w-full max-w-lg rounded-t-2xl"
          style="border-top:1.5px solid rgba(52,48,37,0.58);max-height:90dvh;display:flex;flex-direction:column;overflow:hidden;"
        >
          <%!-- Fixed header --%>
          <div style="padding:20px 20px 12px;flex-shrink:0;">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                Edit member
              </p>
              <button
                type="button"
                phx-click="close_edit"
                style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
              >
                <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>
          </div>

          <form phx-submit="save_member" style="display:contents;">
            <%!-- Scrollable fields --%>
            <div style="overflow-y:auto;flex:1;min-height:0;padding:0 20px 12px;display:flex;flex-direction:column;gap:12px;">
              <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
                <div>
                  <label class="dark-label">First name</label>
                  <input
                    class="dark-input"
                    type="text"
                    name="member[first_name]"
                    value={@editing_member.user.first_name || ""}
                    placeholder="First name"
                  />
                </div>
                <div>
                  <label class="dark-label">Last name</label>
                  <input
                    class="dark-input"
                    type="text"
                    name="member[last_name]"
                    value={@editing_member.user.last_name || ""}
                    placeholder="Last name"
                  />
                </div>
              </div>

              <div>
                <label class="dark-label">Email</label>
                <input
                  class="dark-input"
                  type="email"
                  name="member[email]"
                  value={to_string(@editing_member.user.email)}
                  placeholder="member@example.com"
                />
              </div>

              <div style="height:1px;background:rgba(52,48,37,0.58);margin:4px 0;"></div>

              <div>
                <label class="dark-label">Role</label>
                <select class="dark-select" name="member[role]">
                  <option
                    :for={{label, val} <- role_options(@current_member)}
                    value={val}
                    selected={@editing_member.role == val}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <div>
                <label class="dark-label">
                  Display title <span style="color:#6E675A;font-weight:400;">(optional)</span>
                </label>
                <input
                  class="dark-input"
                  type="text"
                  name="member[display_title]"
                  value={@editing_member.display_title || ""}
                  placeholder="e.g. Lead Gardener"
                />
              </div>

              <div>
                <label class="dark-label">Hourly rate</label>
                <input
                  class="dark-input"
                  type="number"
                  name="member[labor_hourly_rate]"
                  value={@editing_member.labor_hourly_rate}
                  min="0"
                  step="0.01"
                  placeholder="0.00"
                />
              </div>
            </div>

            <%!-- Fixed footer --%>
            <div style="padding:16px 20px;padding-bottom:max(16px,env(safe-area-inset-bottom));flex-shrink:0;">
              <.glow_button type="submit" valid={true}>
                Save changes
              </.glow_button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Tax rate sheet --%>
      <div
        :if={@show_tax_sheet}
        class="z-[60] fixed inset-0 flex items-end justify-center"
        role="dialog"
        aria-label={if @editing_tax_rate, do: "Edit tax rate", else: "Add tax rate"}
      >
        <div class="bg-black/50 absolute inset-0" phx-click="close_tax_form" aria-hidden="true" />
        <div
          class="bg-[#211E16] relative w-full max-w-lg rounded-t-2xl"
          style="border-top:1.5px solid rgba(52,48,37,0.58);max-height:90dvh;display:flex;flex-direction:column;overflow:hidden;"
        >
          <div style="padding:20px 20px 12px;flex-shrink:0;">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                {if @editing_tax_rate, do: "Edit tax rate", else: "Add tax rate"}
              </p>
              <button
                type="button"
                phx-click="close_tax_form"
                style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
              >
                <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>
          </div>

          <div style="overflow-y:auto;flex:1;min-height:0;padding:0 20px 12px;display:flex;flex-direction:column;gap:12px;">
            <div>
              <label class="dark-label">Name</label>
              <input
                class="dark-input"
                type="text"
                name="name"
                value={@tax_params["name"]}
                placeholder="e.g. GST, PST, VAT"
                phx-blur="update_tax_field"
                phx-value-field="name"
              />
            </div>
            <div>
              <label class="dark-label">Rate (%)</label>
              <input
                class="dark-input"
                type="number"
                name="rate"
                value={@tax_params["rate"]}
                min="0"
                step="0.001"
                placeholder="5.0"
                phx-blur="update_tax_field"
                phx-value-field="rate"
              />
            </div>
            <div>
              <label class="dark-label">
                Registration number <span style="color:#6E675A;font-weight:400;">(optional)</span>
              </label>
              <input
                class="dark-input"
                type="text"
                name="registration_number"
                value={@tax_params["registration_number"]}
                placeholder="e.g. 123456789 RT0001"
                phx-blur="update_tax_field"
                phx-value-field="registration_number"
              />
            </div>

            <button
              type="button"
              phx-click="toggle_tax_compound"
              ontouchstart=""
              style="display:flex;align-items:center;justify-content:space-between;width:100%;background:#16140E;border:1px solid rgba(52,48,37,0.58);border-radius:12px;padding:12px 14px;cursor:pointer;text-align:left;"
            >
              <div>
                <div style="font-size:13.5px;font-weight:600;color:#F4EFE2;">Compound tax</div>
                <div style="font-size:12px;color:#9A9384;margin-top:2px;">
                  Applied on top of prior non-compound taxes
                </div>
              </div>
              <div style={"width:40px;height:24px;border-radius:999px;flex-shrink:0;transition:background 0.15s;position:relative;#{if @tax_params["is_compound"], do: "background:#54B57E;", else: "background:#3A3528;"}"}>
                <div style={"width:18px;height:18px;border-radius:999px;background:#fff;position:absolute;top:3px;transition:left 0.15s;#{if @tax_params["is_compound"], do: "left:19px;", else: "left:3px;"}"}>
                </div>
              </div>
            </button>
          </div>

          <div style="padding:16px 20px;padding-bottom:max(16px,env(safe-area-inset-bottom));flex-shrink:0;">
            <.glow_button type="button" phx-click="save_tax_rate" valid={tax_rate_valid?(@tax_params)}>
              {if @editing_tax_rate, do: "Save changes", else: "Add tax rate"}
            </.glow_button>
          </div>
        </div>
      </div>

      <%!-- Sign-off item sheet --%>
      <div
        :if={@show_sign_off_sheet}
        class="z-[60] fixed inset-0 flex items-end justify-center"
        role="dialog"
        aria-label={if @editing_sign_off_index, do: "Edit sign-off item", else: "Add sign-off item"}
      >
        <div class="bg-black/50 absolute inset-0" phx-click="close_sign_off_form" aria-hidden="true" />
        <div
          class="bg-[#211E16] relative w-full max-w-lg rounded-t-2xl"
          style="border-top:1.5px solid rgba(52,48,37,0.58);max-height:90dvh;display:flex;flex-direction:column;overflow:hidden;"
        >
          <div style="padding:20px 20px 12px;flex-shrink:0;">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <p style="font-family:'Bricolage Grotesque',sans-serif;font-size:17px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
                {if @editing_sign_off_index, do: "Edit item", else: "Add sign-off item"}
              </p>
              <button
                type="button"
                phx-click="close_sign_off_form"
                style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
              >
                <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>
          </div>

          <div style="overflow-y:auto;flex:1;min-height:0;padding:0 20px 12px;display:flex;flex-direction:column;gap:14px;">
            <div>
              <label class="dark-label">Checkbox label <span style="color:#E87E7E;">*</span></label>
              <input
                class="dark-input"
                type="text"
                name="label"
                value={@sign_off_params["label"]}
                placeholder="I agree to the payment terms listed above"
                phx-blur="update_sign_off_field"
                phx-value-field="label"
              />
              <p style="font-size:11px;color:#6E675A;margin-top:4px;">
                The text that appears beside the checkbox the client must tick.
              </p>
            </div>
            <div>
              <label class="dark-label">
                Terms text <span style="color:#6E675A;font-weight:400;">(optional)</span>
              </label>
              <textarea
                class="dark-textarea"
                name="body"
                rows="5"
                placeholder="Payment is due within 30 days of invoice. Overdue balances accrue interest at 24% per annum…"
                phx-blur="update_sign_off_field"
                phx-value-field="body"
              >{@sign_off_params["body"]}</textarea>
              <p style="font-size:11px;color:#6E675A;margin-top:4px;">
                Shown above the checkbox. Leave blank if no text is needed.
              </p>
            </div>
          </div>

          <div style="padding:16px 20px;padding-bottom:max(16px,env(safe-area-inset-bottom));flex-shrink:0;">
            <.glow_button
              type="button"
              phx-click="save_sign_off_item"
              valid={String.trim(@sign_off_params["label"] || "") != ""}
            >
              {if @editing_sign_off_index, do: "Save changes", else: "Add item"}
            </.glow_button>
          </div>
        </div>
      </div>

      <.form
        for={@form}
        id="org-form"
        phx-change="validate_org"
        phx-submit="save_org"
        style="padding:16px 16px 96px;display:flex;flex-direction:column;gap:20px;"
      >
        <%!-- Back --%>
        <div style="padding:4px 0;">
          <.link
            navigate={~p"/manage/account"}
            style="display:inline-flex;align-items:center;gap:6px;color:#6E675A;text-decoration:none;font-size:13px;font-weight:600;"
          >
            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 12H5M12 19l-7-7 7-7"
              />
            </svg>
            Account
          </.link>
        </div>

        <%!-- Org name header --%>
        <div style="font-family:'Bricolage Grotesque',sans-serif;font-size:24px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
          {@org.name}
        </div>

        <%!-- General: names + address --%>
        <div>
          <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            General
          </p>
          <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
            <%!-- Logos — auto-save on upload complete via handle_progress --%>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <%!-- Colour --%>
              <div>
                <label class="dark-label">Colour</label>
                <% colour_url = logo_url(@org.logo_colour_key) %>
                <div style="position:relative;">
                  <div style="aspect-ratio:1;background:#16140E;border-radius:10px;overflow:hidden;display:flex;align-items:center;justify-content:center;border:1px solid rgba(52,48,37,0.58);">
                    <img
                      :if={colour_url}
                      src={colour_url}
                      style="width:100%;height:100%;object-fit:contain;"
                      alt="Colour logo"
                    />
                    <span
                      :if={!colour_url && @uploads.logo_colour.entries == []}
                      style="font-size:11px;color:#6E675A;"
                    >
                      No logo
                    </span>
                    <span
                      :if={@uploads.logo_colour.entries != []}
                      style="font-size:11px;color:#9A9384;"
                    >
                      Uploading…
                    </span>
                  </div>
                  <label
                    :if={@uploads.logo_colour.entries == []}
                    ontouchstart=""
                    style="position:absolute;top:6px;right:6px;width:28px;height:28px;background:rgba(33,30,22,0.85);border:1px solid rgba(52,48,37,0.58);border-radius:8px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#9A9384;"
                  >
                    <.live_file_input upload={@uploads.logo_colour} style="display:none;" />
                    <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                  </label>
                </div>
                <div
                  :for={err <- upload_errors(@uploads.logo_colour)}
                  style="margin-top:4px;font-size:11px;color:#E87E7E;"
                >
                  {upload_error_to_string(err)}
                </div>
                <div
                  :for={entry <- @uploads.logo_colour.entries}
                  style="margin-top:4px;display:flex;align-items:center;justify-content:space-between;"
                >
                  <div
                    :for={err <- upload_errors(@uploads.logo_colour, entry)}
                    style="font-size:11px;color:#E87E7E;"
                  >
                    {upload_error_to_string(err)}
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    phx-value-name="logo_colour"
                    style="color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                  >
                    <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                </div>
                <div
                  :if={@logo_colour_warning}
                  style="display:flex;align-items:flex-start;gap:5px;margin-top:5px;background:rgba(219,146,88,0.1);border:1px solid rgba(219,146,88,0.25);border-radius:7px;padding:6px 8px;"
                >
                  <svg
                    width="12"
                    height="12"
                    fill="none"
                    stroke="#DB9258"
                    viewBox="0 0 24 24"
                    style="flex-shrink:0;margin-top:1px;"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                  <span style="font-size:11px;color:#DB9258;">{@logo_colour_warning}</span>
                </div>
              </div>
              <%!-- Greyscale --%>
              <div>
                <label class="dark-label">Greyscale</label>
                <% grey_url = logo_url(@org.logo_greyscale_key) %>
                <div style="position:relative;">
                  <div style="aspect-ratio:1;background:#16140E;border-radius:10px;overflow:hidden;display:flex;align-items:center;justify-content:center;border:1px solid rgba(52,48,37,0.58);">
                    <img
                      :if={grey_url}
                      src={grey_url}
                      style="width:100%;height:100%;object-fit:contain;"
                      alt="Greyscale logo"
                    />
                    <span
                      :if={!grey_url && @uploads.logo_greyscale.entries == []}
                      style="font-size:11px;color:#6E675A;"
                    >
                      No logo
                    </span>
                    <span
                      :if={@uploads.logo_greyscale.entries != []}
                      style="font-size:11px;color:#9A9384;"
                    >
                      Uploading…
                    </span>
                  </div>
                  <label
                    :if={@uploads.logo_greyscale.entries == []}
                    ontouchstart=""
                    style="position:absolute;top:6px;right:6px;width:28px;height:28px;background:rgba(33,30,22,0.85);border:1px solid rgba(52,48,37,0.58);border-radius:8px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#9A9384;"
                  >
                    <.live_file_input upload={@uploads.logo_greyscale} style="display:none;" />
                    <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                  </label>
                </div>
                <div
                  :for={err <- upload_errors(@uploads.logo_greyscale)}
                  style="margin-top:4px;font-size:11px;color:#E87E7E;"
                >
                  {upload_error_to_string(err)}
                </div>
                <div
                  :for={entry <- @uploads.logo_greyscale.entries}
                  style="margin-top:4px;display:flex;align-items:center;justify-content:space-between;"
                >
                  <div
                    :for={err <- upload_errors(@uploads.logo_greyscale, entry)}
                    style="font-size:11px;color:#E87E7E;"
                  >
                    {upload_error_to_string(err)}
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    phx-value-name="logo_greyscale"
                    style="color:#6E675A;background:none;border:none;padding:0;cursor:pointer;line-height:0;"
                  >
                    <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                </div>
                <div
                  :if={@logo_greyscale_warning}
                  style="display:flex;align-items:flex-start;gap:5px;margin-top:5px;background:rgba(219,146,88,0.1);border:1px solid rgba(219,146,88,0.25);border-radius:7px;padding:6px 8px;"
                >
                  <svg
                    width="12"
                    height="12"
                    fill="none"
                    stroke="#DB9258"
                    viewBox="0 0 24 24"
                    style="flex-shrink:0;margin-top:1px;"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                  <span style="font-size:11px;color:#DB9258;">{@logo_greyscale_warning}</span>
                </div>
              </div>
            </div>

            <div style="height:1px;background:rgba(52,48,37,0.58);"></div>

            <div>
              <label class="dark-label" for={@form[:name].id}>Trading name</label>
              <input
                class="dark-input"
                type="text"
                name={@form[:name].name}
                id={@form[:name].id}
                value={@form[:name].value || ""}
                placeholder="Toto Gardens"
              />
              <span :for={msg <- @form[:name].errors} class="dark-field-error">{elem(msg, 0)}</span>
            </div>
            <div>
              <label class="dark-label" for={@form[:legal_name].id}>
                Legal name <span style="color:#6E675A;font-weight:400;">(optional)</span>
              </label>
              <input
                class="dark-input"
                type="text"
                name={@form[:legal_name].name}
                id={@form[:legal_name].id}
                value={@form[:legal_name].value || ""}
                placeholder="1308-8393 Inc."
              />
            </div>
            <div>
              <label class="dark-label" for={@form[:website].id}>
                Website <span style="color:#6E675A;font-weight:400;">(optional)</span>
              </label>
              <input
                class="dark-input"
                type="url"
                name={@form[:website].name}
                id={@form[:website].id}
                value={@form[:website].value || ""}
                placeholder="totogardens.ca"
              />
            </div>
            <div>
              <label class="dark-label" for={@form[:phone].id}>Phone</label>
              <input
                class="dark-input"
                type="tel"
                name={@form[:phone].name}
                id={@form[:phone].id}
                value={@form[:phone].value || ""}
                placeholder="(613) 555-0100"
                phx-hook="FormatPhone"
              />
            </div>

            <div style="height:1px;background:rgba(52,48,37,0.58);"></div>

            <div>
              <label class="dark-label">Street</label>
              <input
                class="dark-input"
                id="hq-addr-street"
                type="text"
                name="address[street]"
                value={addr(@org.address, :street)}
                placeholder="123 Main St"
              />
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div>
                <label class="dark-label">City</label>
                <input
                  class="dark-input"
                  id="hq-addr-city"
                  type="text"
                  name="address[city]"
                  value={addr(@org.address, :city)}
                  placeholder="Ottawa"
                  phx-hook="TitleCase"
                />
              </div>
              <div>
                <label class="dark-label">Province / State</label>
                <input
                  class="dark-input"
                  id="hq-addr-province"
                  type="text"
                  name="address[province]"
                  value={addr(@org.address, :province)}
                  placeholder="ON"
                />
              </div>
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div>
                <label class="dark-label">Postal code</label>
                <input
                  class="dark-input"
                  id="hq-addr-zip"
                  type="text"
                  name="address[zip]"
                  value={addr(@org.address, :zip)}
                  placeholder="K1A 0A0"
                  phx-hook="FormatPostal"
                />
              </div>
              <div>
                <label class="dark-label">Country</label>
                <input
                  class="dark-input"
                  id="hq-addr-country"
                  type="text"
                  name="address[country]"
                  value={addr(@org.address, :country)}
                  placeholder="Canada"
                  phx-hook="TitleCase"
                />
              </div>
            </div>
          </div>
        </div>

        <%!-- Staff --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Staff
            </p>
            <button
              :if={Roles.can_create_staff?(@current_member)}
              type="button"
              phx-click="open_invite"
              ontouchstart=""
              style="color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2.5"
                  d="M12 5v14M5 12h14"
                />
              </svg>
            </button>
          </div>
          <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);overflow:hidden;">
            <div
              :for={{m, idx} <- Enum.with_index(@members)}
              style={"padding:12px 14px;display:flex;align-items:center;gap:12px;#{if idx > 0, do: "border-top:1px solid rgba(52,48,37,0.58);"}"}
            >
              <div style={"width:36px;height:36px;border-radius:10px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:14px;letter-spacing:-0.01em;color:#fff;opacity:#{if m.status == :suspended, do: "0.45", else: "1"};#{member_gradient(m.role)}"}>
                {member_initial(m)}
              </div>
              <div style="flex:1;min-width:0;">
                <div style={"font-size:13.5px;font-weight:600;line-height:1.3;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;#{if m.status == :suspended, do: "color:#6E675A;", else: "color:#F4EFE2;"}"}>
                  {member_display_name(m)}
                </div>
                <div style={"margin-top:2px;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;#{if m.status == :suspended, do: "color:#6E675A;", else: "color:#9A9384;"}"}>
                  {if m.display_title, do: m.display_title, else: role_label(m.role)}
                </div>
                <div :if={m.status == :suspended} style="margin-top:3px;">
                  <span style="font-size:10.5px;font-weight:700;letter-spacing:0.03em;padding:2px 7px;border-radius:999px;background:rgba(232,126,126,0.14);color:#E87E7E;">
                    Suspended
                  </span>
                </div>
              </div>
              <div
                :if={Roles.can_manage_members?(@current_member)}
                style="display:flex;align-items:center;gap:6px;flex-shrink:0;"
              >
                <button
                  type="button"
                  phx-click="open_edit"
                  phx-value-id={m.id}
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Edit"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                    />
                  </svg>
                </button>
                <button
                  :if={m.id != @current_member.id && m.status == :active}
                  type="button"
                  phx-click="suspend_member"
                  phx-value-id={m.id}
                  ontouchstart=""
                  style="color:#E87E7E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Suspend"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                    />
                  </svg>
                </button>
                <button
                  :if={m.id != @current_member.id && m.status == :suspended}
                  type="button"
                  phx-click="activate_member"
                  phx-value-id={m.id}
                  ontouchstart=""
                  style="color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Restore access"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Pricing: currency + tax settings + costs --%>
        <div>
          <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            Pricing
          </p>
          <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
            <div>
              <label class="dark-label" for={@form[:currency].id}>Currency</label>
              <select class="dark-select" name={@form[:currency].name} id={@form[:currency].id}>
                <option
                  :for={
                    {label, val} <- [
                      {"Canadian Dollar (CAD)", :CAD},
                      {"US Dollar (USD)", :USD},
                      {"Euro (EUR)", :EUR}
                    ]
                  }
                  value={val}
                  selected={to_string(@form[:currency].value) == to_string(val)}
                >
                  {label}
                </option>
              </select>
            </div>
            <div>
              <label class="dark-label" for={@form[:tax_mode].id}>Tax mode</label>
              <select class="dark-select" name={@form[:tax_mode].name} id={@form[:tax_mode].id}>
                <option
                  :for={
                    {label, val} <- [
                      {"Exclusive — add tax on top", :exclusive},
                      {"Inclusive — price includes tax", :inclusive}
                    ]
                  }
                  value={val}
                  selected={to_string(@form[:tax_mode].value) == to_string(val)}
                >
                  {label}
                </option>
              </select>
            </div>
            <div>
              <label class="dark-label" for={@form[:labor_overhead_percent].id}>
                Labour overhead %
              </label>
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
              <span :for={msg <- @form[:labor_overhead_percent].errors} class="dark-field-error">
                {elem(msg, 0)}
              </span>
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
              <span :for={msg <- @form[:mileage_cost_per_km].errors} class="dark-field-error">
                {elem(msg, 0)}
              </span>
            </div>
          </div>
        </div>

        <%!-- Tax rates --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Tax rates
            </p>
            <button
              :if={Roles.manager_or_above?(@current_member)}
              type="button"
              phx-click="open_tax_form"
              ontouchstart=""
              style="color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            >
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2.5"
                  d="M12 5v14M5 12h14"
                />
              </svg>
            </button>
          </div>
          <div
            :if={@tax_rates == []}
            style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:20px 16px;text-align:center;"
          >
            <p style="font-size:13px;color:#6E675A;">No tax rates configured</p>
          </div>
          <div
            :if={@tax_rates != []}
            style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);overflow:hidden;"
          >
            <div
              :for={{rate, idx} <- Enum.with_index(@tax_rates)}
              style={"padding:12px 14px;display:flex;align-items:center;gap:10px;#{if idx > 0, do: "border-top:1px solid rgba(52,48,37,0.58);"}"}
            >
              <div
                :if={Roles.manager_or_above?(@current_member)}
                style="display:flex;flex-direction:column;gap:1px;flex-shrink:0;"
              >
                <button
                  type="button"
                  phx-click="move_tax_up"
                  phx-value-id={rate.id}
                  ontouchstart=""
                  disabled={idx == 0}
                  style={"color:#{if idx == 0, do: "#3A3528", else: "#6E675A"};background:none;border:none;padding:2px;cursor:#{if idx == 0, do: "default", else: "pointer"};line-height:0;"}
                  aria-label="Move up"
                >
                  <svg width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2.5"
                      d="M5 15l7-7 7 7"
                    />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="move_tax_down"
                  phx-value-id={rate.id}
                  ontouchstart=""
                  disabled={idx == length(@tax_rates) - 1}
                  style={"color:#{if idx == length(@tax_rates) - 1, do: "#3A3528", else: "#6E675A"};background:none;border:none;padding:2px;cursor:#{if idx == length(@tax_rates) - 1, do: "default", else: "pointer"};line-height:0;"}
                  aria-label="Move down"
                >
                  <svg width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2.5"
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                </button>
              </div>
              <div style="flex:1;min-width:0;">
                <div style="display:flex;align-items:center;gap:8px;">
                  <span style="font-size:13.5px;font-weight:600;color:#F4EFE2;">{rate.name}</span>
                  <span style="font-size:13px;color:#9A9384;">{Decimal.to_string(rate.rate)}%</span>
                  <span
                    :if={rate.is_compound}
                    style="font-size:10.5px;font-weight:700;letter-spacing:0.03em;padding:2px 7px;border-radius:999px;background:rgba(90,180,216,0.14);color:#5AB4D8;"
                  >
                    compound
                  </span>
                </div>
                <div
                  :if={rate.registration_number}
                  style="margin-top:2px;font-size:11.5px;color:#6E675A;"
                >
                  Reg: {rate.registration_number}
                </div>
              </div>
              <div
                :if={Roles.manager_or_above?(@current_member)}
                style="display:flex;align-items:center;gap:4px;flex-shrink:0;"
              >
                <button
                  type="button"
                  phx-click="open_tax_form"
                  phx-value-id={rate.id}
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Edit"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                    />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="delete_tax_rate"
                  phx-value-id={rate.id}
                  ontouchstart=""
                  style="color:#E87E7E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Delete"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                    />
                  </svg>
                </button>
              </div>
            </div>
            <div
              :if={length(@tax_rates) > 1}
              style="border-top:1px solid rgba(52,48,37,0.58);padding:10px 14px;display:flex;justify-content:space-between;align-items:center;"
            >
              <span style="font-size:12px;color:#6E675A;">Effective total</span>
              <span style="font-size:13px;font-weight:600;color:#9A9384;">
                {effective_tax_rate(@tax_rates)}%
              </span>
            </div>
          </div>
        </div>

        <%!-- Invoice --%>
        <div>
          <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            Invoice
          </p>
          <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
            <div>
              <label class="dark-label" for={@form[:next_invoice_number].id}>
                Next invoice number
              </label>
              <input
                class="dark-input"
                type="number"
                min="1"
                step="1"
                name={@form[:next_invoice_number].name}
                id={@form[:next_invoice_number].id}
                value={@form[:next_invoice_number].value || 1}
              />
              <span :for={msg <- @form[:next_invoice_number].errors} class="dark-field-error">
                {elem(msg, 0)}
              </span>
            </div>
            <div>
              <label class="dark-label" for={@form[:payment_info].id}>Payment info</label>
              <textarea
                class="dark-textarea"
                name={@form[:payment_info].name}
                id={@form[:payment_info].id}
                rows="3"
                placeholder="E.g. E-transfer to pay@example.com — include invoice number in memo"
              >{@form[:payment_info].value || ""}</textarea>
            </div>
            <div>
              <label class="dark-label" for={@form[:invoice_terms].id}>Terms</label>
              <textarea
                class="dark-textarea"
                name={@form[:invoice_terms].name}
                id={@form[:invoice_terms].id}
                rows="3"
                placeholder="E.g. Payment due within 30 days. Overdue balances subject to 1.5% monthly interest."
              >{@form[:invoice_terms].value || ""}</textarea>
            </div>
            <div>
              <label class="dark-label" for={@form[:invoice_annual_nominal_rate].id}>
                Annual nominal rate (%)
              </label>
              <input
                class="dark-input"
                type="number"
                min="0"
                max="35"
                step="0.01"
                name={@form[:invoice_annual_nominal_rate].name}
                id={@form[:invoice_annual_nominal_rate].id}
                value={@form[:invoice_annual_nominal_rate].value || ""}
                placeholder="e.g. 24"
              />
              <span :for={msg <- @form[:invoice_annual_nominal_rate].errors} class="dark-field-error">
                {elem(msg, 0)}
              </span>
            </div>
            <div>
              <label class="dark-label" for={@form[:invoice_footer].id}>Footer</label>
              <textarea
                class="dark-textarea"
                name={@form[:invoice_footer].name}
                id={@form[:invoice_footer].id}
                rows="2"
                placeholder="E.g. Thank you for your business!"
              >{@form[:invoice_footer].value || ""}</textarea>
            </div>
          </div>
        </div>

        <%!-- Contact --%>
        <div>
          <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            Contact
          </p>
          <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;display:flex;flex-direction:column;gap:14px;">
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div>
                <label class="dark-label" for={@form[:contact_name].id}>Name</label>
                <input
                  class="dark-input"
                  type="text"
                  name={@form[:contact_name].name}
                  id={@form[:contact_name].id}
                  value={@form[:contact_name].value || ""}
                  placeholder="Jane Smith"
                />
              </div>
              <div>
                <label class="dark-label" for={@form[:contact_title].id}>Title</label>
                <input
                  class="dark-input"
                  type="text"
                  name={@form[:contact_title].name}
                  id={@form[:contact_title].id}
                  value={@form[:contact_title].value || ""}
                  placeholder="Office Manager"
                />
              </div>
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div>
                <label class="dark-label" for={@form[:contact_phone].id}>Phone</label>
                <input
                  class="dark-input"
                  type="tel"
                  name={@form[:contact_phone].name}
                  id={@form[:contact_phone].id}
                  value={@form[:contact_phone].value || ""}
                  placeholder="(613) 555-0101"
                  phx-hook="FormatPhone"
                />
              </div>
              <div>
                <label class="dark-label" for={@form[:contact_email].id}>Email</label>
                <input
                  class="dark-input"
                  type="email"
                  name={@form[:contact_email].name}
                  id={@form[:contact_email].id}
                  value={@form[:contact_email].value || ""}
                  placeholder="jane@example.com"
                />
              </div>
            </div>
          </div>
        </div>

        <%!-- Email --%>
        <div>
          <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            Email
          </p>
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

        <%!-- Estimate sign-off items --%>
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <div>
              <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
                Estimate sign-off
              </p>
              <p style="font-size:11px;color:#6E675A;margin-top:2px;">
                Items the client must acknowledge before signing an estimate.
              </p>
            </div>
            <button
              :if={Roles.manager_or_above?(@current_member)}
              type="button"
              phx-click="open_sign_off_form"
              ontouchstart=""
              style="color:#54B57E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;flex-shrink:0;"
            >
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2.5"
                  d="M12 5v14M5 12h14"
                />
              </svg>
            </button>
          </div>
          <div
            :if={@sign_off_items == []}
            style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:20px 16px;text-align:center;"
          >
            <p style="font-size:13px;color:#6E675A;">
              No sign-off items — clients can sign immediately
            </p>
          </div>
          <div
            :if={@sign_off_items != []}
            style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);overflow:hidden;"
          >
            <div
              :for={{item, idx} <- Enum.with_index(@sign_off_items)}
              style={"padding:12px 14px;display:flex;align-items:flex-start;gap:10px;#{if idx > 0, do: "border-top:1px solid rgba(52,48,37,0.58);"}"}
            >
              <div style="flex:1;min-width:0;">
                <p style="font-size:13.5px;font-weight:600;color:#F4EFE2;line-height:1.3;">
                  {item["label"]}
                </p>
                <p
                  :if={item["body"]}
                  style="font-size:11.5px;color:#6E675A;margin-top:3px;line-height:1.4;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;"
                >
                  {item["body"]}
                </p>
              </div>
              <div
                :if={Roles.manager_or_above?(@current_member)}
                style="display:flex;align-items:center;gap:4px;flex-shrink:0;"
              >
                <button
                  type="button"
                  phx-click="open_sign_off_form"
                  phx-value-index={idx}
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Edit"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                    />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="remove_sign_off_item"
                  phx-value-index={idx}
                  ontouchstart=""
                  style="color:#E87E7E;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
                  aria-label="Remove"
                >
                  <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                    />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>

        <.glow_button type="submit" valid={true}>
          Save changes
        </.glow_button>
      </.form>
    </div>
    """
  end

  # -- Helpers --

  defp role_options(actor) do
    roles =
      if Roles.can_promote_to_owner?(actor),
        do: [:owner, :manager, :staff],
        else: [:manager, :staff]

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

  defp effective_tax_rate(rates) do
    simple =
      rates
      |> Enum.reject(& &1.is_compound)
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.rate))

    compound =
      rates
      |> Enum.filter(& &1.is_compound)
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.rate))

    total = Decimal.add(simple, Decimal.mult(compound, Decimal.add(1, Decimal.div(simple, 100))))

    total
    |> Decimal.round(4)
    |> Decimal.to_string()
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp tax_rate_valid?(%{"name" => name, "rate" => rate}) do
    trimmed = String.trim(name || "")
    trimmed != "" and match?({_, ""}, Decimal.parse(to_string(rate || "0")))
  end

  defp upsert_org_address(org, address_params) do
    alias OpenSauce.CRM

    if org.address do
      CRM.update_address(org.address, address_params, authorize?: false)
    else
      any_value = Enum.any?(Map.values(address_params), & &1)

      if any_value do
        CRM.create_address(Map.put(address_params, "organisation_id", org.id), authorize?: false)
      end
    end
  end

  defp nilify(""), do: nil
  defp nilify(s), do: s

  defp nilify_map_values(map), do: Map.new(map, fn {k, v} -> {k, nilify(v)} end)

  defp addr(nil, _), do: ""
  defp addr(address, field), do: Map.get(address, field) || ""

  defp parse_rate(nil), do: 0
  defp parse_rate(""), do: 0

  defp parse_rate(s) do
    case Decimal.parse(to_string(s)) do
      {d, ""} -> d
      _ -> 0
    end
  end

  # -- Logo helpers --

  defp logo_url(nil), do: nil

  defp logo_url(key) do
    case OpenSauce.Storage.url(key) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  defp upload_error_to_string(:too_large), do: "File too large (max 10 MB)"
  defp upload_error_to_string(:not_accepted), do: "Must be a PNG file"
  defp upload_error_to_string(:too_many_files), do: "Only one file allowed"
  defp upload_error_to_string(err), do: inspect(err)

  # Min dimension for a sharp half-width render on a high-density display.
  # Half of ~430pt at 4× DPR is ~860px; 800 is a round number just under that.
  # Update every few years as phone screen densities improve.
  @min_logo_px 800

  defp process_logo_file(path, org, storage_filename, label) do
    data = File.read!(path)

    case png_dimensions(data) do
      :error ->
        {:error, "Could not read PNG header from #{label}."}

      {w, h} when w != h ->
        {:error, "#{label} must be square — got #{w}×#{h}px."}

      {size, _} ->
        case OpenSauce.Storage.put("orgs/#{org.id}", storage_filename, "image/png", data) do
          {:ok, key} when size < @min_logo_px ->
            {:warn, key,
             "#{label} is #{size}px — may look soft on high-density screens (#{@min_logo_px}px+ recommended)."}

          {:ok, key} ->
            {:ok, key}

          {:error, reason} ->
            {:error, "Could not store #{label}: #{inspect(reason)}"}
        end
    end
  end

  # PNG IHDR: 8-byte signature + 4-byte chunk length + 4-byte "IHDR" = 16 bytes, then width + height
  defp png_dimensions(<<_::bytes-size(16), w::32-big, h::32-big, _::binary>>), do: {w, h}
  defp png_dimensions(_), do: :error
end
