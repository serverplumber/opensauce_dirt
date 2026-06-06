defmodule OpenSauceWeb.OrgPickLive do
  use OpenSauceWeb, :live_view_blank

  alias OpenSauce.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    memberships = Accounts.list_memberships_for_user!(user.id, authorize?: false)

    case memberships do
      [] ->
        {:ok, push_navigate(socket, to: ~p"/org/new")}

      [single] ->
        {:ok, push_navigate(socket, to: ~p"/org/pick/#{single.organisation_id}")}

      many ->
        sorted = Enum.sort_by(many, & &1.inserted_at, {:desc, DateTime})

        {:ok,
         assign(socket,
           memberships: sorted,
           greeting_name: greeting_name(user.email)
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="min-height:100dvh;background:#16140E;font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;display:flex;flex-direction:column;">

      <%!-- top bar --%>
      <div style="height:64px;flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;padding:0 24px;">
        <div style="display:flex;align-items:center;gap:9px;font-family:'Bricolage Grotesque',sans-serif;font-weight:800;font-size:17px;letter-spacing:-0.02em;color:#3D9A63;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
            <path d="M12 22v-8" stroke="#54B57E" stroke-width="2" stroke-linecap="round"/>
            <path d="M12 15c0-3.3 0-5 2-7 1.4-1.4 3.6-1.5 4.6-1.5 0 2.1-.6 4.3-2.1 5.8C14.8 13.9 12 15 12 15Z" fill="#54B57E"/>
            <path d="M12 16c0-2.7-.7-4-2.7-5.4C7.9 9.7 5.8 9.6 4.9 9.6c.1 1.9.9 3.6 2.3 4.7C8.8 15.4 12 16 12 16Z" fill="#5BB97F"/>
          </svg>
          OpenSauce
        </div>
        <a href={~p"/sign-out"} style="font-size:13px;font-weight:600;color:#9A9384;text-decoration:none;">Sign out</a>
      </div>

      <%!-- body --%>
      <div style="padding:6px 24px 40px;flex:1;display:flex;flex-direction:column;">
        <div style="font-family:'Bricolage Grotesque',sans-serif;font-size:27px;font-weight:700;letter-spacing:-0.02em;">
          G'day, {@greeting_name} 👋
        </div>
        <div style="margin-top:7px;font-size:14px;color:#9A9384;line-height:1.5;">
          You're signed in. Pick where you're working today.
        </div>

        <%!-- org list --%>
        <div style="margin-top:24px;display:flex;flex-direction:column;gap:12px;">
          <a
            :for={{m, idx} <- Enum.with_index(@memberships)}
            href={~p"/org/pick/#{m.organisation_id}"}
            style={org_card_style(m.role, idx == 0)}
          >
            <span :if={idx == 0} style="position:absolute;top:14px;right:15px;font-size:10.5px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#54B57E;">
              Last used
            </span>
            <div style={"width:50px;height:50px;border-radius:14px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:23px;color:#fff;#{monogram_gradient(m.role)}"}>
              {org_initial(m.organisation.name)}
            </div>
            <div style="flex:1;min-width:0;">
              <div style="font-size:16px;font-weight:700;color:#F4EFE2;letter-spacing:-0.01em;">{m.organisation.name}</div>
              <span style={"display:inline-flex;align-items:center;margin-top:6px;font-size:11.5px;font-weight:700;letter-spacing:0.02em;padding:3px 9px;border-radius:999px;#{role_pill_style(m.role)}"}>
                {role_label(m.role)}
              </span>
            </div>
            <svg style={"flex:0 0 auto;#{chevron_color(m.role, idx == 0)}"} width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M9 6l6 6-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </a>
        </div>

        <%!-- create org --%>
        <a
          href={~p"/org/new"}
          style="margin-top:16px;border:1.5px dashed rgba(52,48,37,0.8);border-radius:18px;background:rgba(255,255,255,0.025);padding:16px;display:flex;align-items:center;gap:14px;text-decoration:none;transition:background .12s ease;"
        >
          <div style="width:50px;height:50px;border-radius:14px;flex:0 0 auto;background:rgba(84,181,126,0.14);display:flex;align-items:center;justify-content:center;color:#54B57E;">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M12 5v14M5 12h14" stroke="#54B57E" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <div>
            <div style="font-size:15px;font-weight:700;color:#F4EFE2;">Create a new organisation</div>
            <div style="margin-top:3px;font-size:12.5px;color:#9A9384;">Set up your company in a couple of minutes</div>
          </div>
        </a>
      </div>
    </div>
    """
  end

  defp greeting_name(email) do
    email
    |> to_string()
    |> String.split("@")
    |> hd()
    |> String.split(~r/[._\-+]/)
    |> hd()
    |> String.capitalize()
  end

  defp org_initial(name) do
    name |> String.trim() |> String.first() |> String.upcase()
  end

  defp org_card_style(_role, last_used) do
    border =
      if last_used,
        do: "border-color:#54B57E;box-shadow:0 0 0 3px rgba(84,181,126,0.30),0 1px 2px rgba(0,0,0,0.4),0 12px 30px rgba(0,0,0,0.45);",
        else: "border-color:rgba(52,48,37,0.58);box-shadow:0 1px 2px rgba(0,0,0,0.4),0 12px 30px rgba(0,0,0,0.45);"

    "background:#211E16;border:1.5px solid;#{border}border-radius:18px;padding:15px;display:flex;align-items:center;gap:14px;position:relative;text-decoration:none;"
  end

  defp monogram_gradient(:owner), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp monogram_gradient(:manager), do: "background:linear-gradient(135deg,#BE6E37,#8A4D24);"
  defp monogram_gradient(_), do: "background:linear-gradient(135deg,#54B57E,#173A2B);"

  defp role_pill_style(:owner), do: "background:rgba(219,146,88,0.16);color:#DB9258;"
  defp role_pill_style(:manager), do: "background:rgba(219,146,88,0.16);color:#DB9258;"
  defp role_pill_style(_), do: "background:rgba(84,181,126,0.14);color:#54B57E;"

  defp role_label(:owner), do: "Owner"
  defp role_label(:manager), do: "Manager"
  defp role_label(_), do: "Field crew"

  defp chevron_color(_role, true), do: "color:#54B57E;"
  defp chevron_color(:owner, _), do: "color:#DB9258;"
  defp chevron_color(:manager, _), do: "color:#DB9258;"
  defp chevron_color(_, _), do: "color:#6E675A;"
end
