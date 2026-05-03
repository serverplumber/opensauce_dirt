defmodule OpenSauceWeb.StorageLocationLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Operations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id={"storage-location-form-#{@id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" placeholder="Walk-in Fridge" />
        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, build_form(assigns))}
  end

  @impl true
  def handle_event("validate", %{"storage_location" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "storage_location"))}
  end

  @impl true
  def handle_event("save", %{"storage_location" => params}, socket) do
    save(socket, socket.assigns.action, params)
  end

  defp save(socket, :new, params) do
    attrs = Map.put(params, "venue_id", socket.assigns.venue.id)

    case Operations.create_storage_location(attrs, socket.assigns.opts) do
      {:ok, loc} ->
        notify_parent({:location_saved, loc})
        {:noreply, socket}

      {:error, error} ->
        require Logger
        Logger.error("create_storage_location failed: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Could not save location.")}
    end
  end

  defp save(socket, :edit, params) do
    case Operations.update_storage_location(socket.assigns.location, params, socket.assigns.opts) do
      {:ok, loc} ->
        notify_parent({:location_saved, loc})
        {:noreply, socket}

      {:error, error} ->
        require Logger
        Logger.error("update_storage_location failed: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Could not save location.")}
    end
  end

  defp build_form(%{action: :new}),
    do: to_form(%{"name" => ""}, as: "storage_location")

  defp build_form(%{action: :edit, location: loc}),
    do: to_form(%{"name" => loc.name}, as: "storage_location")

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
