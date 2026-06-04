defmodule OpenSauceWeb.MobileSignInLive do
  use OpenSauceWeb, :live_view_blank

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, state: :enter_email, email: "")}
  end

  @impl true
  def handle_event("submit_email", %{"email" => email}, socket) do
    trimmed = String.trim(email)

    request_magic_link(trimmed)

    {:noreply, assign(socket, state: :check_email, email: trimmed)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, state: :enter_email, email: "")}
  end

  @impl true
  def handle_event("resend", _params, socket) do
    request_magic_link(socket.assigns.email)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-stone-50 flex flex-col items-center justify-center px-6 py-12">
      <div class="w-full max-w-sm space-y-8">
        <.flash_group flash={@flash} />

        <div class="text-center">
          <svg
            class="mx-auto h-10 w-10"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 66 54"
            fill="none"
          >
            <path
              d="M21.1262 0.100903C11.2779 1.06643 3.22266 5.53542 0.850231 11.3286C-0.418743 14.501 0.160571 18.0045 2.42266 20.7907L3.19507 21.7562L3.05714 30.2528C2.91921 39.3012 2.97438 40.0184 3.71922 41.5633C4.46405 43.1357 5.23647 43.6322 9.62271 45.4805C18.9745 49.4254 24.0504 51.2737 27.5539 52.0737C28.7677 52.3495 32.1884 52.7082 32.7401 52.5978C35.4987 52.1013 58.1472 47.0254 58.7265 46.7495C59.1679 46.5288 59.7196 46.0874 59.9955 45.7012C60.961 44.3771 60.9886 44.0736 61.0989 33.6184L61.2093 23.9907L61.6782 23.6321C62.6713 22.9149 63.9679 21.3976 64.492 20.3493C66.8093 15.632 64.2989 10.6665 58.092 7.63199C50.9195 4.12852 40.6022 1.25953 31.3884 0.211249C29.2366 0.0181442 22.9469 -0.0922018 21.1262 0.100903Z"
              fill="currentColor"
            />
          </svg>
          <h1 class="mt-4 text-2xl font-bold text-stone-900">Sign in</h1>
        </div>

        <div :if={@state == :enter_email} class="space-y-4">
          <p class="text-sm text-stone-500 text-center">
            We'll send a sign-in link to your email.
          </p>
          <form phx-submit="submit_email" id="sign-in-form" class="space-y-4">
            <div>
              <label for="email" class="block text-sm font-medium text-stone-700">
                Email address
              </label>
              <input
                id="email"
                name="email"
                type="email"
                inputmode="email"
                autocomplete="email"
                value={@email}
                required
                autofocus
                placeholder="you@example.com"
                class="mt-1.5 block w-full rounded-xl border border-stone-300 bg-white px-4 py-3 text-sm shadow-sm placeholder:text-stone-400 focus:border-stone-500 focus:outline-none focus:ring-1 focus:ring-stone-500"
              />
            </div>
            <button
              id="send-magic-link-btn"
              type="submit"
              class="w-full rounded-xl bg-stone-900 px-4 py-3 text-sm font-semibold text-white hover:bg-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-500 focus:ring-offset-2 transition"
            >
              Send magic link
            </button>
          </form>
        </div>

        <div :if={@state == :check_email} class="space-y-6 text-center">
          <div class="rounded-2xl border border-stone-200 bg-white px-6 py-8 space-y-3">
            <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-stone-100">
              <svg class="h-6 w-6 text-stone-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                />
              </svg>
            </div>
            <h2 class="text-lg font-semibold text-stone-900">Check your email</h2>
            <p class="text-sm text-stone-500">
              We sent a sign-in link to
            </p>
            <p class="text-sm font-medium text-stone-900 break-all">{@email}</p>
          </div>

          <div class="space-y-3">
            <button
              id="resend-btn"
              type="button"
              phx-click="resend"
              phx-hook="CooldownButton"
              data-cooldown="30"
              class="w-full rounded-xl border border-stone-300 px-4 py-3 text-sm font-medium text-stone-700 hover:bg-stone-100 transition focus:outline-none focus:ring-2 focus:ring-stone-400 focus:ring-offset-2"
            >
              Resend link
            </button>
            <button
              id="different-email-btn"
              type="button"
              phx-click="reset"
              class="w-full text-sm text-stone-500 hover:text-stone-800 transition py-1"
            >
              Use a different email
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp request_magic_link(email) do
    OpenSauce.Accounts.User
    |> Ash.Query.for_read(:request_magic_link, %{email: email})
    |> Ash.read(authorize?: false)

    :ok
  end
end
