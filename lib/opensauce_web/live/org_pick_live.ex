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
        {:ok, assign(socket, :memberships, sorted)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-stone-50 flex flex-col items-center justify-center px-6 py-12">
      <div class="w-full max-w-sm space-y-6">
        <div>
          <h1 class="text-2xl font-bold text-stone-900">Choose an organisation</h1>
          <p class="mt-1 text-sm text-stone-500">Select the organisation you want to work in.</p>
        </div>

        <ul class="space-y-2">
          <li :for={m <- @memberships}>
            <a
              href={~p"/org/pick/#{m.organisation_id}"}
              class="flex w-full items-center justify-between rounded-xl border border-stone-200 bg-white px-4 py-4 shadow-sm hover:border-stone-300 hover:bg-stone-50 transition"
            >
              <div>
                <p class="text-sm font-semibold text-stone-900">{m.organisation.name}</p>
                <p class="text-xs text-stone-400 mt-0.5 capitalize">{m.role}</p>
              </div>
              <svg class="h-4 w-4 text-stone-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </a>
          </li>
        </ul>

        <div class="pt-2">
          <.link
            navigate={~p"/org/new"}
            class="flex w-full items-center justify-center gap-2 rounded-xl border border-dashed border-stone-300 px-4 py-3.5 text-sm font-medium text-stone-500 hover:border-stone-400 hover:text-stone-700 transition"
          >
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Create another organisation
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
