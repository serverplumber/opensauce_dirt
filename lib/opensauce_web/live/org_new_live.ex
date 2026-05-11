defmodule OpenSauceWeb.OrgNewLive do
  @moduledoc false
  use OpenSauceWeb, :live_view_blank

  alias OpenSauce.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, name: "", slug: "")}
  end

  @impl true
  def handle_event("change", %{"name" => name}, socket) do
    {:noreply, assign(socket, name: name, slug: slugify(name))}
  end

  @impl true
  def handle_event("create", %{"name" => name}, socket) do
    user = socket.assigns.current_user
    slug = slugify(name)

    with {:ok, org} <- Accounts.create_organisation(%{name: name, slug: slug}, authorize?: false),
         {:ok, _member} <-
           Accounts.create_organisation_member(
             %{user_id: user.id, organisation_id: org.id, role: :owner},
             authorize?: false
           ) do
      {:noreply, redirect(socket, to: ~p"/org/pick/#{org.id}")}
    else
      {:error, error} ->
        message =
          case error do
            %Ash.Error.Invalid{errors: [%{message: msg} | _]} -> msg
            _ -> "Something went wrong. Please try again."
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid h-screen place-items-center bg-stone-50">
      <div class="w-full max-w-sm space-y-6 px-4">
        <div>
          <h1 class="text-2xl font-bold text-stone-900">Create your organisation</h1>
          <p class="mt-1 text-sm text-stone-500">
            You can add team members and change settings after setup.
          </p>
        </div>

        <form phx-submit="create" phx-change="change" class="space-y-4">
          <div>
            <label for="name" class="block text-sm font-medium text-stone-700">
              Organisation name
            </label>
            <input
              id="name"
              name="name"
              type="text"
              value={@name}
              placeholder="Acme Bakery"
              required
              autofocus
              class="mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-sm shadow-sm focus:border-stone-500 focus:outline-none focus:ring-1 focus:ring-stone-500"
            />
            <p :if={@slug != ""} class="mt-1 text-xs text-stone-400">
              Slug: <span class="font-mono">{@slug}</span>
            </p>
          </div>

          <button
            type="submit"
            class="w-full rounded-md bg-stone-900 px-4 py-2 text-sm font-medium text-white hover:bg-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-500 focus:ring-offset-2"
          >
            Create organisation
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
