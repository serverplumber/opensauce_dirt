defmodule OpenSauceWeb.VenueLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Operations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <form
        id={"venue-form-#{@venue.id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        style="display:flex;flex-direction:column;gap:16px;"
      >
        <div>
          <label class="dark-label">Name</label>
          <input
            class="dark-input"
            type="text"
            name="venue[name]"
            value={@form.params["name"] || ""}
            placeholder="Nursery"
            required
          />
        </div>
        <div>
          <label class="dark-label">Address</label>
          <input
            class="dark-input"
            type="text"
            name="venue[address]"
            value={@form.params["address"] || ""}
            placeholder="123 Baker St"
          />
        </div>
        <.glow_button valid={true} type="submit">Save</.glow_button>
      </form>
    </div>
    """
  end

  @impl true
  def update(%{venue: venue} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, build_form(venue))}
  end

  @impl true
  def handle_event("validate", %{"venue" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "venue"))}
  end

  @impl true
  def handle_event("save", %{"venue" => params}, socket) do
    case Operations.update_venue(socket.assigns.venue, params, socket.assigns.opts) do
      {:ok, venue} ->
        notify_parent({:venue_saved, venue})
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save venue.")}
    end
  end

  defp build_form(v),
    do: to_form(%{"name" => v.name, "address" => v.address || ""}, as: "venue")

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
