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
    <div class="min-h-dvh flex flex-col items-center justify-center bg-stone-50 px-6 py-12">
      <div class="w-full max-w-sm space-y-8">
        <div>
          <h1 class="text-2xl font-bold text-stone-900">Create your organisation</h1>
          <p class="mt-1 text-sm text-stone-500">
            Add team members and update settings after setup.
          </p>
        </div>

        <.flash_group flash={@flash} />

        <form phx-submit="create" phx-change="change" class="space-y-5" id="new-org-form">
          <div>
            <label for="org-name" class="block text-sm font-medium text-stone-700">
              Organisation name
            </label>
            <input
              id="org-name"
              name="name"
              type="text"
              value={@name}
              placeholder="Acme Gardens"
              required
              autofocus
              class="mt-1.5 block w-full rounded-xl border border-stone-300 bg-white px-4 py-3 text-sm shadow-sm placeholder:text-stone-400 focus:border-stone-500 focus:outline-none focus:ring-1 focus:ring-stone-500"
            />
            <p :if={@slug != ""} class="mt-1.5 text-xs text-stone-400">
              Slug: <span class="font-mono">{@slug}</span>
            </p>
          </div>

          <button
            id="create-org-btn"
            type="submit"
            class="w-full rounded-xl bg-stone-900 px-4 py-3 text-sm font-semibold text-white transition hover:bg-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-500 focus:ring-offset-2"
          >
            Create organisation
          </button>
        </form>

        <div class="text-center">
          <.link
            navigate={~p"/org/pick"}
            class="text-sm text-stone-400 transition hover:text-stone-700"
          >
            ← Back to organisation list
          </.link>
        </div>
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
