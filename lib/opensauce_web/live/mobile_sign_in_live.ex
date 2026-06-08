defmodule OpenSauceWeb.MobileSignInLive do
  use OpenSauceWeb, :live_view_blank

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, state: :enter_email, email: "", email_error: nil)}
  end

  @impl true
  def handle_event("submit_email", %{"email" => email}, socket) do
    trimmed = String.trim(email)

    cond do
      trimmed == "" ->
        {:noreply, assign(socket, email_error: "Enter your work email to continue.")}

      not String.contains?(trimmed, "@") ->
        {:noreply, assign(socket, email_error: "That doesn't look like a valid email address.")}

      true ->
        request_magic_link(trimmed)
        {:noreply, assign(socket, state: :check_email, email: trimmed, email_error: nil)}
    end
  end

  @impl true
  def handle_event("update_email", %{"email" => email}, socket) do
    {:noreply, assign(socket, email: email, email_error: nil)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, state: :enter_email, email: "", email_error: nil)}
  end

  @impl true
  def handle_event("resend", _params, socket) do
    request_magic_link(socket.assigns.email)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dark-screen" style="min-height:100dvh;background:#16140E;font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <.flash_group flash={@flash} />

      <%!-- L1: enter email --%>
      <div :if={@state == :enter_email} style="min-height:100dvh;display:flex;flex-direction:column;">
        <%!-- green hero panel --%>
        <div style="background:radial-gradient(130% 120% at 80% -20%,#245A40 0%,#1C4631 45%,#0E2419 100%);padding:56px 30px 46px;border-bottom-left-radius:34px;border-bottom-right-radius:34px;position:relative;overflow:hidden;">
          <%!-- watermark leaf --%>
          <svg style="position:absolute;right:-28px;top:30px;opacity:0.13;transform:rotate(8deg);" width="180" height="180" viewBox="0 0 24 24" fill="none">
            <path d="M12 21c0-5 0-8 3-11 2-2 5-2 6-2 0 3-1 6-3 8-2.4 2.4-6 5-6 5Z" fill="#fff"/>
            <path d="M12 21c0-4-1-6-4-8-1.6-1.1-4-1.3-5-1.3.2 2.6 1.3 4.8 3.2 6.2C8.4 19.4 12 21 12 21Z" fill="#fff"/>
          </svg>
          <%!-- sprout + wordmark --%>
          <div style="display:flex;align-items:center;gap:12px;">
            <svg width="34" height="34" viewBox="0 0 24 24" fill="none">
              <path d="M12 22v-8" stroke="#9FD9B2" stroke-width="2" stroke-linecap="round"/>
              <path d="M12 15c0-3.3 0-5 2-7 1.4-1.4 3.6-1.5 4.6-1.5 0 2.1-.6 4.3-2.1 5.8C14.8 13.9 12 15 12 15Z" fill="#3D9A63"/>
              <path d="M12 16c0-2.7-.7-4-2.7-5.4C7.9 9.7 5.8 9.6 4.9 9.6c.1 1.9.9 3.6 2.3 4.7C8.8 15.4 12 16 12 16Z" fill="#5BB97F"/>
            </svg>
            <span style="font-family:'Bricolage Grotesque',sans-serif;font-weight:800;font-size:27px;color:#fff;letter-spacing:-0.02em;">OpenSauce</span>
          </div>
          <div style="margin-top:22px;font-size:12px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;color:#6BCB93;">Dirt · field ops</div>
          <div style="margin-top:9px;font-family:'Bricolage Grotesque',sans-serif;font-size:25px;line-height:1.22;font-weight:600;color:#F4EFE2;letter-spacing:-0.01em;max-width:250px;">
            Jobs, crews &amp; gardens — in your pocket.
          </div>
        </div>

        <%!-- body --%>
        <div style="flex:1;padding:30px 30px 26px;display:flex;flex-direction:column;">
          <h2 style="font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:23px;letter-spacing:-0.02em;color:#F4EFE2;">Sign in</h2>
          <p style="margin-top:7px;font-size:14.5px;color:#9A9384;line-height:1.5;">Enter your work email and we'll send a one-tap link. No password to remember.</p>

          <form phx-submit="submit_email" phx-change="update_email" id="sign-in-form" novalidate style="margin-top:26px;display:flex;flex-direction:column;">
            <label style="font-size:13px;font-weight:600;color:#CFC8B8;letter-spacing:0.01em;margin-bottom:8px;">Work email</label>
            <div id="email-field" style="height:56px;background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:14px;display:flex;align-items:center;gap:11px;padding:0 16px;">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="14" rx="3" stroke="#54B57E" stroke-width="1.8"/><path d="M4 7l8 6 8-6" stroke="#54B57E" stroke-width="1.8" stroke-linecap="round"/></svg>
              <input
                id="email"
                name="email"
                type="email"
                inputmode="email"
                autocomplete="email"
                value={@email}
                autofocus
                style="border:none;outline:none;background:transparent;flex:1;font-family:'Hanken Grotesk',sans-serif;font-size:16px;color:#F4EFE2;"
              />
            </div>
            <div :if={@email_error} style="display:flex;align-items:center;gap:7px;margin-top:8px;color:#E07B5A;font-size:13px;line-height:1.4;">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" style="flex:0 0 auto;"><circle cx="12" cy="12" r="10" stroke="#E07B5A" stroke-width="1.8"/><path d="M12 8v4" stroke="#E07B5A" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="16" r="1" fill="#E07B5A"/></svg>
              {@email_error}
            </div>
            <div style="height:14px;"></div>
            <.glow_button type="submit" valid={valid_email?(@email)}>
              Email me a magic link
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M5 12h13M13 6l6 6-6 6" stroke="#0C1F15" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </.glow_button>
            <div style="height:16px;"></div>
            <div style="display:flex;align-items:center;gap:9px;color:#9A9384;font-size:13px;line-height:1.4;">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="5" y="11" width="14" height="9" rx="2" stroke="#9A9384" stroke-width="1.7"/><path d="M8 11V8a4 4 0 0 1 8 0v3" stroke="#9A9384" stroke-width="1.7"/></svg>
              <span>The link signs you in on this phone. It works once.</span>
            </div>
          </form>

          <p style="margin-top:auto;padding-top:26px;font-size:11.5px;color:#6E675A;text-align:center;line-height:1.5;">
            By continuing you agree to our Terms &amp; Privacy Policy.
          </p>
        </div>
      </div>

      <%!-- L2: check email --%>
      <div :if={@state == :check_email} style="min-height:100dvh;display:flex;flex-direction:column;">
        <%!-- back button --%>
        <div style="height:56px;flex:0 0 auto;display:flex;align-items:center;padding:0 18px;">
          <button
            type="button"
            phx-click="reset"
            style="width:40px;height:40px;border-radius:12px;border:1.5px solid rgba(52,48,37,0.58);background:#211E16;display:flex;align-items:center;justify-content:center;cursor:pointer;"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M15 6l-6 6 6 6" stroke="#9A9384" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </button>
        </div>

        <%!-- centred content --%>
        <div style="flex:1;display:flex;flex-direction:column;align-items:center;text-align:center;padding:14px 32px 30px;">
          <div style="width:92px;height:92px;border-radius:26px;background:rgba(84,181,126,0.14);border:1.5px solid rgba(84,181,126,0.35);display:flex;align-items:center;justify-content:center;margin-top:36px;">
            <svg width="46" height="46" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="5" width="18" height="14" rx="3" stroke="#54B57E" stroke-width="1.7"/>
              <path d="M4 7l8 6 8-6" stroke="#54B57E" stroke-width="1.7" stroke-linecap="round"/>
              <circle cx="19" cy="6" r="4" fill="#3D9A63"/>
              <path d="M17.4 6l1.1 1.1 2-2.2" stroke="#fff" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>

          <h2 style="font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:25px;letter-spacing:-0.02em;color:#F4EFE2;margin-top:26px;">Check your email</h2>
          <p style="margin-top:12px;font-size:14.5px;color:#9A9384;">We sent a one-tap sign-in link to</p>
          <p style="margin-top:5px;font-size:16px;font-weight:700;color:#F4EFE2;word-break:break-all;">{@email}</p>
          <p style="margin-top:16px;font-size:13.5px;color:#9A9384;line-height:1.5;max-width:240px;">
            Tap the link on this phone and you're in. It works once and expires in 15&nbsp;minutes.
          </p>

          <div style="width:100%;margin-top:30px;display:flex;flex-direction:column;gap:12px;">
            <.glow_button href="mailto:">
              Open mail app
            </.glow_button>
            <div style="display:flex;gap:22px;justify-content:center;margin-top:2px;">
              <button
                id="resend-btn"
                type="button"
                phx-click="resend"
                phx-hook="CooldownButton"
                data-cooldown="30"
                style="background:none;border:none;cursor:pointer;font-family:'Hanken Grotesk',sans-serif;font-size:13.5px;font-weight:600;color:#54B57E;padding:0;"
              >
                Resend link
              </button>
              <button
                type="button"
                phx-click="reset"
                style="background:none;border:none;cursor:pointer;font-family:'Hanken Grotesk',sans-serif;font-size:13.5px;font-weight:600;color:#9A9384;padding:0;"
              >
                Use a different email
              </button>
            </div>
          </div>

          <p style="margin-top:auto;padding-top:24px;font-size:12.5px;color:#9A9384;">
            Can't find it? Check your spam folder.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp valid_email?(email) do
    trimmed = String.trim(email)
    trimmed != "" and String.contains?(trimmed, "@")
  end

  defp request_magic_link(email) do
    OpenSauce.Accounts.User
    |> Ash.Query.for_read(:request_magic_link, %{email: email})
    |> Ash.read(authorize?: false)

    :ok
  end
end
