defmodule OpenSauceWeb.VenueLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Operations
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :nav_sub_links, fn -> [] end)

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
      :if={@show_venue_modal}
      id="edit-venue-modal"
      show
      title="Edit Venue"
      on_cancel={JS.push("close_venue_modal")}
    >
      <.simple_form for={@venue_form} id="venue-form" phx-change="validate_venue" phx-submit="save_venue">
        <.input field={@venue_form[:name]} type="text" label="Name" />
        <.input field={@venue_form[:address]} type="text" label="Address" />
        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </.modal>

    <.modal
      :if={@show_location_modal}
      id="location-modal"
      show
      title={if @editing_location, do: "Edit Location", else: "New Location"}
      on_cancel={JS.push("close_location_modal")}
    >
      <.simple_form
        for={@location_form}
        id="location-form"
        phx-change="validate_location"
        phx-submit="save_location"
      >
        <.input field={@location_form[:name]} type="text" label="Name" placeholder="Walk-in Fridge" />
        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    venue = Operations.get_venue!(id, opts(socket))
    locations = Operations.list_storage_locations_for_venue!(id, opts(socket))

    {:ok,
     socket
     |> assign(:venue, venue)
     |> assign(:storage_locations, locations)
     |> assign(:show_venue_modal, false)
     |> assign(:show_location_modal, false)
     |> assign(:editing_location, nil)
     |> assign(:venue_form, venue_form(venue))
     |> assign(:location_form, empty_location_form())}
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
  def handle_event("edit_venue", _, socket) do
    {:noreply, assign(socket, :show_venue_modal, true)}
  end

  @impl true
  def handle_event("close_venue_modal", _, socket) do
    {:noreply, assign(socket, :show_venue_modal, false)}
  end

  @impl true
  def handle_event("validate_venue", %{"venue" => params}, socket) do
    {:noreply, assign(socket, :venue_form, to_form(params, as: "venue"))}
  end

  @impl true
  def handle_event("save_venue", %{"venue" => params}, socket) do
    case Operations.update_venue(socket.assigns.venue, params, opts(socket)) do
      {:ok, venue} ->
        {:noreply,
         socket
         |> assign(:venue, venue)
         |> assign(:venue_form, venue_form(venue))
         |> assign(:show_venue_modal, false)
         |> put_flash(:info, "Venue updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update venue.")}
    end
  end

  @impl true
  def handle_event("new_location", _, socket) do
    {:noreply,
     socket
     |> assign(:show_location_modal, true)
     |> assign(:editing_location, nil)
     |> assign(:location_form, empty_location_form())}
  end

  @impl true
  def handle_event("edit_location", %{"id" => id}, socket) do
    loc = Enum.find(socket.assigns.storage_locations, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:show_location_modal, true)
     |> assign(:editing_location, loc)
     |> assign(:location_form, location_form(loc))}
  end

  @impl true
  def handle_event("close_location_modal", _, socket) do
    {:noreply, assign(socket, show_location_modal: false, editing_location: nil)}
  end

  @impl true
  def handle_event("validate_location", %{"storage_location" => params}, socket) do
    {:noreply, assign(socket, :location_form, to_form(params, as: "storage_location"))}
  end

  @impl true
  def handle_event("save_location", %{"storage_location" => params}, socket) do
    result =
      if loc = socket.assigns.editing_location do
        Operations.update_storage_location(loc, params, opts(socket))
      else
        Operations.create_storage_location(
          params
          |> Map.put("venue_id", socket.assigns.venue.id)
          |> Map.put("organisation_id", socket.assigns.current_member.organisation_id),
          opts(socket)
        )
      end

    case result do
      {:ok, _} ->
        locations = Operations.list_storage_locations_for_venue!(socket.assigns.venue.id, opts(socket))

        {:noreply,
         socket
         |> assign(:storage_locations, locations)
         |> assign(:show_location_modal, false)
         |> assign(:editing_location, nil)
         |> assign(:location_form, empty_location_form())
         |> put_flash(:info, "Location saved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save location.")}
    end
  end

  @impl true
  def handle_event("delete_location", %{"id" => id}, socket) do
    loc = Enum.find(socket.assigns.storage_locations, &(&1.id == id))
    Operations.delete_storage_location!(loc, opts(socket))
    locations = Operations.list_storage_locations_for_venue!(socket.assigns.venue.id, opts(socket))

    {:noreply,
     socket
     |> assign(:storage_locations, locations)
     |> put_flash(:info, "Location deleted.")}
  end

  defp venue_form(v), do: to_form(%{"name" => v.name, "address" => v.address || ""}, as: "venue")
  defp empty_location_form, do: to_form(%{"name" => ""}, as: "storage_location")
  defp location_form(loc), do: to_form(%{"name" => loc.name}, as: "storage_location")

  defp opts(socket) do
    [actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id]
  end
end
