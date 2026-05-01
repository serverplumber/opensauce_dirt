defmodule OpenSauceWeb.OrgPickLive do
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    memberships = Accounts.list_memberships_for_user!(user.id, authorize?: false)

    case memberships do
      [single] ->
        {:ok, push_navigate(socket, to: ~p"/org/pick/#{single.organisation_id}")}

      many ->
        {:ok, assign(socket, :memberships, many)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="grid h-screen place-items-center">
      <div class="w-full max-w-sm space-y-4">
        <h1 class="text-2xl font-bold text-stone-900">Choose an organisation</h1>
        <ul class="space-y-2">
          <li :for={m <- @memberships}>
            <a
              href={~p"/org/pick/#{m.organisation_id}"}
              class="flex w-full items-center justify-between rounded-md border border-stone-300 bg-stone-50 px-4 py-3 text-sm font-medium hover:bg-stone-100"
            >
              <span>{m.organisation.name}</span>
              <span class="text-xs text-stone-400">{m.role}</span>
            </a>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
