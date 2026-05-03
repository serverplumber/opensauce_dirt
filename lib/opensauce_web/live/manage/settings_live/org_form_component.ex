defmodule OpenSauceWeb.SettingsLive.OrgFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts.Roles

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form :if={Roles.owner?(@current_member)}
        for={@form}
        id="org-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <section
          id="organisation-settings"
          aria-labelledby="organisation-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="organisation-settings-title" class="text-base font-semibold text-stone-800">
              Organisation
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              Your organisation's display name shown across the app.
            </p>
          </div>
          <div class="space-y-4 p-4">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Acme Bakery" />
          </div>
        </section>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Organisation</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    form =
      AshPhoenix.Form.for_update(assigns.organisation, :update,
        as: "organisation",
        actor: assigns.current_member
      )

    {:ok, socket |> assign(assigns) |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"organisation" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"organisation" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, organisation} ->
        notify_parent({:saved, organisation})
        {:noreply, put_flash(socket, :info, "Organisation updated.")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
