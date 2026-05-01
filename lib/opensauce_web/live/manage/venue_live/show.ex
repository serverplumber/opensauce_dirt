defmodule OpenSauceWeb.VenueLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Operations
  alias OpenSauceWeb.Navigation
  alias OpenSauceWeb.StorageLocationLive.FormComponent, as: LocationForm
  alias OpenSauceWeb.VenueLive.FormComponent, as: VenueForm

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        {@venue.name}
        <:actions>
          <.button variant={:secondary} phx-click="edit_venue">
            <.icon name="hero-pencil-square" class="-ml-1 mr-2 h-4 w-4" /> Edit
          </.button>
        </:actions>
      </.header>

      <div :if={@venue.address} class="rounded-md border border-gray-200 bg-white p-4">
        <p class="text-xs font-medium uppercase tracking-wide text-stone-500">Address</p>
        <p class="mt-1 text-sm text-stone-800">{@venue.address}</p>
      </div>

      <div class="rounded-md border border-gray-200 bg-white">
        <div class="flex items-center justify-between border-b border-gray-200 px-4 py-3">
          <h3 class="text-base font-semibold text-stone-800">Storage Locations</h3>
          <.button size={:sm} variant={:primary} phx-click="new_location">
            <.icon name="hero-plus" class="-ml-1 mr-1.5 h-3.5 w-3.5" /> Add
          </.button>
        </div>
        <.table id="storage-locations" rows={@storage_locations} wrapper_class="mt-0">
          <:col :let={loc} label="Name">{loc.name}</:col>
          <:action :let={loc}>
            <.button size={:sm} variant={:secondary} phx-click="edit_location" phx-value-id={loc.id}>
              Edit
            </.button>
            <.button
              size={:sm}
              variant={:danger}
              phx-click="delete_location"
              phx-value-id={loc.id}
              data-confirm={"Delete #{loc.name}?"}
            >
              Delete
            </.button>
          </:action>
          <:empty>
            <div class="py-6 text-center text-sm text-stone-500">No storage locations yet.</div>
          </:empty>
        </.table>
      </div>
    </div>

    <.modal
      :if={@active_modal == :venue}
      id="edit-venue-modal"
      show
      title="Edit Venue"
      on_cancel={JS.push("close_modal")}
    >
      <.live_component
        module={VenueForm}
        id={"venue-#{@venue.id}"}
        venue={@venue}
        opts={@opts}
      />
    </.modal>

    <.modal
      :if={@active_modal == :location}
      id="location-modal"
      show
      title={if @location_action == :edit, do: "Edit Location", else: "New Location"}
      on_cancel={JS.push("close_modal")}
    >
      <.live_component
        module={LocationForm}
        id={"location-form"}
        action={@location_action}
        location={@editing_location}
        venue={@venue}
        opts={@opts}
      />
    </.modal>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    opts = build_opts(socket)
    venue = Operations.get_venue!(id, opts)
    locations = Operations.list_storage_locations_for_venue!(id, opts)

    {:ok,
     socket
     |> assign(:venue, venue)
     |> assign(:storage_locations, locations)
     |> assign(:opts, opts)
     |> assign(:active_modal, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)
     |> assign(:nav_sub_links, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    trail = [Navigation.root(:venues), %{label: socket.assigns.venue.name, path: nil}]

    {:noreply,
     socket
     |> assign(:page_title, socket.assigns.venue.name)
     |> Navigation.assign(:venues, trail)}
  end

  @impl true
  def handle_event("edit_venue", _, socket),
    do: {:noreply, assign(socket, :active_modal, :venue)}

  @impl true
  def handle_event("new_location", _, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, :location)
     |> assign(:location_action, :new)
     |> assign(:editing_location, nil)}
  end

  @impl true
  def handle_event("edit_location", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.storage_locations, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Location not found.")}

      loc ->
        {:noreply,
         socket
         |> assign(:active_modal, :location)
         |> assign(:location_action, :edit)
         |> assign(:editing_location, loc)}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)}
  end

  @impl true
  def handle_event("delete_location", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.storage_locations, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Location not found.")}

      loc ->
        Operations.delete_storage_location!(loc, socket.assigns.opts)
        {:noreply,
         socket
         |> reload_locations()
         |> put_flash(:info, "Location deleted.")}
    end
  end

  @impl true
  def handle_info({VenueForm, {:venue_saved, venue}}, socket) do
    {:noreply,
     socket
     |> assign(:venue, venue)
     |> assign(:active_modal, nil)
     |> put_flash(:info, "Venue updated.")}
  end

  @impl true
  def handle_info({LocationForm, {:location_saved, _loc}}, socket) do
    {:noreply,
     socket
     |> reload_locations()
     |> assign(:active_modal, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)
     |> put_flash(:info, "Location saved.")}
  end

  defp reload_locations(socket) do
    locations =
      Operations.list_storage_locations_for_venue!(socket.assigns.venue.id, socket.assigns.opts)

    assign(socket, :storage_locations, locations)
  end

  defp build_opts(socket) do
    member = socket.assigns.current_member
    [actor: member, tenant: member.organisation_id]
  end
end
