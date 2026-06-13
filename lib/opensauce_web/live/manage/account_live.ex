defmodule OpenSauceWeb.AccountLive do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias AshPhoenix.Form
  alias OpenSauce.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    member = socket.assigns.current_member

    org = Accounts.get_organisation!(member.organisation_id, authorize?: false)

    memberships = Accounts.list_memberships_for_user!(user.id, authorize?: false)

    form = Form.for_update(user, :update, authorize?: false, domain: Accounts, as: "account")

    {:ok,
     socket
     |> assign(:main_bg, "bg-[#16140E]")
     |> assign(:page_title, "Account")
     |> assign(:org, org)
     |> assign(:memberships_count, length(memberships))
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"account" => params}, socket) do
    form = Form.validate(socket.assigns.form.source, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save", %{"account" => params}, socket) do
    case Form.submit(socket.assigns.form.source, params: params) do
      {:ok, updated_user} ->
        user = Ash.load!(updated_user, [:initials], authorize?: false, domain: Accounts)
        form = Form.for_update(user, :update, authorize?: false, domain: Accounts, as: "account")

        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:form, to_form(form))
         |> put_flash(:info, "Name updated.")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding:16px;display:flex;flex-direction:column;gap:20px;font-family:'Hanken Grotesk',system-ui,sans-serif;">

      <%!-- Hero: avatar + name + email + role --%>
      <div style="display:flex;align-items:center;gap:14px;padding:4px 0;">
        <div style={"width:56px;height:56px;border-radius:14px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:22px;color:#fff;letter-spacing:-0.02em;#{hero_monogram_gradient(@current_member)}"}>
          {@current_user.initials}
        </div>
        <div style="flex:1;min-width:0;">
          <div style="font-family:'Bricolage Grotesque',sans-serif;font-size:20px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {hero_display_name(@current_user)}
          </div>
          <div style="margin-top:3px;font-size:12.5px;color:#9A9384;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
            {@current_user.email}
          </div>
          <span style={"display:inline-flex;align-items:center;margin-top:6px;font-size:11px;font-weight:700;letter-spacing:0.04em;padding:2px 8px;border-radius:999px;#{role_pill_style(@current_member)}"}>
            {role_label(@current_member)}
          </span>
        </div>
      </div>

      <%!-- Profile form --%>
      <div>
        <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
          Profile
        </p>
        <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);padding:16px;">
          <.form
            for={@form}
            id="account-form"
            phx-change="validate"
            phx-submit="save"
          >
            <div style="display:flex;flex-direction:column;gap:14px;">
              <div>
                <label class="dark-label" for={@form[:first_name].id}>First name</label>
                <input
                  class="dark-input"
                  type="text"
                  name={@form[:first_name].name}
                  id={@form[:first_name].id}
                  value={@form[:first_name].value || ""}
                  placeholder="First name"
                  phx-debounce="blur"
                />
                <span :for={msg <- @form[:first_name].errors} class="dark-field-error">{elem(msg, 0)}</span>
              </div>
              <div>
                <label class="dark-label" for={@form[:last_name].id}>Last name</label>
                <input
                  class="dark-input"
                  type="text"
                  name={@form[:last_name].name}
                  id={@form[:last_name].id}
                  value={@form[:last_name].value || ""}
                  placeholder="Last name"
                  phx-debounce="blur"
                />
                <span :for={msg <- @form[:last_name].errors} class="dark-field-error">{elem(msg, 0)}</span>
              </div>
              <div :if={@current_member.display_title}>
                <label class="dark-label">Display title</label>
                <div style="font-size:14px;color:#9A9384;padding:10px 0 2px;">
                  {@current_member.display_title}
                </div>
              </div>
            </div>
            <div style="margin-top:16px;">
              <.glow_button type="submit" valid={name_changed?(@form, @current_user)}>
                Save name
              </.glow_button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- Organisation --%>
      <div>
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
          <p style="font-size:11.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
            Organisation
          </p>
          <.link :if={@current_member.role == :owner} navigate={~p"/manage/org"} style="color:#6E675A;line-height:0;padding:4px;">
            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
          </.link>
        </div>
        <div style="background:#211E16;border-radius:16px;border:1px solid rgba(52,48,37,0.58);overflow:hidden;">
          <div style="padding:14px 16px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <div style="font-size:16px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">
              {@org.name}
            </div>
          </div>
          <div style="padding:12px 16px;display:flex;flex-direction:column;gap:10px;">
            <.org_row label="Currency" value={to_string(@org.currency)} />
            <.org_row label="Tax mode" value={tax_mode_label(@org.tax_mode)} />
            <.org_row label="Labour overhead" value={"#{@org.labor_overhead_percent}%"} />
            <.org_row label="Mileage rate" value={"#{@org.mileage_cost_per_km}/km"} />
          </div>
        </div>
      </div>

      <%!-- Actions --%>
      <div style="display:flex;flex-direction:column;gap:10px;padding-bottom:12px;">
        <.link
          :if={@memberships_count > 1}
          navigate={~p"/org/pick"}
          style="display:flex;align-items:center;justify-content:space-between;background:#211E16;border-radius:14px;border:1px solid rgba(52,48,37,0.58);padding:14px 16px;text-decoration:none;"
        >
          <span style="font-size:14px;font-weight:600;color:#F4EFE2;">Switch organisation</span>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <path d="M9 6l6 6-6 6" stroke="#6E675A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </.link>

        <button
          type="button"
          ontouchstart=""
          phx-click={JS.show(to: "#sign-out-sheet")}
          style="display:flex;align-items:center;justify-content:space-between;background:#211E16;border-radius:14px;border:1px solid rgba(52,48,37,0.58);padding:14px 16px;width:100%;text-align:left;cursor:pointer;"
        >
          <span style="font-size:14px;font-weight:600;color:#E87E7E;">Sign out</span>
          <svg width="18" height="18" fill="none" stroke="#E87E7E" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp org_row(assigns) do
    ~H"""
    <div style="display:flex;align-items:center;justify-content:space-between;">
      <span style="font-size:13px;color:#6E675A;">{@label}</span>
      <span style="font-size:13px;font-weight:600;color:#9A9384;">{@value}</span>
    </div>
    """
  end

  defp hero_display_name(user) do
    cond do
      user.first_name && user.last_name -> "#{user.first_name} #{user.last_name}"
      user.first_name -> user.first_name
      true -> user.email |> to_string() |> String.split("@") |> hd() |> String.capitalize()
    end
  end

  defp hero_monogram_gradient(%{role: role}) when role in [:owner, :manager],
    do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"

  defp hero_monogram_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"

  defp role_pill_style(%{role: role}) when role in [:owner, :manager],
    do: "background:rgba(219,146,88,0.16);color:#DB9258;"

  defp role_pill_style(_), do: "background:rgba(84,181,126,0.14);color:#54B57E;"

  defp role_label(%{role: :owner}), do: "Owner"
  defp role_label(%{role: :manager}), do: "Manager"
  defp role_label(_), do: "Field crew"

  defp tax_mode_label(:inclusive), do: "Inclusive"
  defp tax_mode_label(:exclusive), do: "Exclusive"
  defp tax_mode_label(other), do: to_string(other) |> String.capitalize()

  defp name_changed?(form, user) do
    first = (form[:first_name].value || "") |> to_string() |> String.trim()
    last = (form[:last_name].value || "") |> to_string() |> String.trim()
    current_first = (user.first_name || "") |> String.trim()
    current_last = (user.last_name || "") |> String.trim()
    first != current_first or last != current_last
  end
end
