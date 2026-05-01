defmodule OpenSauceWeb.VenueLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Operations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id={"venue-form-#{@venue.id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:address]} type="text" label="Address" />
        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
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
        {:noreply, socket}
    end
  end

  defp build_form(v),
    do: to_form(%{"name" => v.name, "address" => v.address || ""}, as: "venue")

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
