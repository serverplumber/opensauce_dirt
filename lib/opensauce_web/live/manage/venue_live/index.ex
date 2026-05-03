defmodule OpenSauceWeb.VenueLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Operations
  alias OpenSauceWeb.Navigation
  alias OpenSauceWeb.StorageLocationLive.FormComponent, as: LocationForm

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :nav_sub_links, fn -> [] end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>Production sites and storage spaces.</:subtitle>
        Venues
        <:actions>
          <.button variant={:primary} phx-click="new_venue">
            <.icon name="hero-plus" class="-ml-1 mr-2 h-4 w-4" /> New Venue
          </.button>
        </:actions>
      </.header>

      <div
        :if={@venues == []}
        class="rounded-md border border-gray-200 bg-white px-4 py-6 text-center text-sm text-stone-500"
      >
        No venues yet. Add one to start tracking storage locations.
      </div>

      <div class="space-y-4">
        <div :for={venue <- @venues} class="rounded-md border border-gray-200 bg-white">
          <div class="flex items-center justify-between border-b border-gray-200 px-4 py-3">
            <div>
              <.link
                navigate={~p"/manage/venues/#{venue.id}"}
                class="text-base font-semibold text-stone-900 hover:underline"
              >
                {venue.name}
              </.link>
              <p :if={venue.address} class="mt-0.5 text-xs text-stone-500">{venue.address}</p>
            </div>
            <div class="flex gap-2">
              <.button size={:sm} variant={:secondary} phx-click="edit_venue" phx-value-id={venue.id}>
                Edit
              </.button>
              <.button
                size={:sm}
                variant={:danger}
                phx-click="delete_venue"
                phx-value-id={venue.id}
                data-confirm={"Delete #{venue.name}? This cannot be undone."}
              >
                Delete
              </.button>
            </div>
          </div>

          <div class="flex items-center justify-between border-b border-gray-100 px-4 py-2">
            <span class="text-xs font-medium uppercase tracking-wide text-stone-500">
              Storage Locations
            </span>
            <.button
              size={:sm}
              variant={:secondary}
              phx-click="new_location"
              phx-value-venue-id={venue.id}
            >
              <.icon name="hero-plus" class="-ml-0.5 mr-1 h-3 w-3" /> Add
            </.button>
          </div>

          <p
            :if={venue.storage_locations == []}
            class="px-4 py-3 text-sm text-stone-400"
          >
            No storage locations yet.
          </p>

          <ul :if={venue.storage_locations != []} class="divide-y divide-gray-100">
            <li
              :for={loc <- venue.storage_locations}
              class="flex items-center justify-between px-4 py-2 text-sm text-stone-800"
            >
              {loc.name}
              <div class="flex gap-2">
                <.button
                  size={:sm}
                  variant={:secondary}
                  phx-click="edit_location"
                  phx-value-id={loc.id}
                  phx-value-venue-id={venue.id}
                >
                  Edit
                </.button>
                <.button
                  size={:sm}
                  variant={:danger}
                  phx-click="delete_location"
                  phx-value-id={loc.id}
                  phx-value-venue-id={venue.id}
                  data-confirm={"Delete #{loc.name}?"}
                >
                  Delete
                </.button>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <.modal
      :if={@active_modal == :venue}
      id="venue-modal"
      show
      title={if @editing_venue, do: "Edit Venue", else: "New Venue"}
      on_cancel={JS.push("close_modal")}
    >
      <.simple_form for={@form} id="venue-form" phx-change="validate_venue" phx-submit="save_venue">
        <.input field={@form[:name]} type="text" label="Name" placeholder="Main Kitchen" />
        <.input field={@form[:address]} type="text" label="Address" placeholder="123 Baker St" />
        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
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
        id="location-form"
        action={@location_action}
        location={@editing_location}
        venue={@active_venue}
        opts={@opts}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    o = opts(socket)

    {:ok,
     socket
     |> assign(:opts, o)
     |> assign(:active_modal, nil)
     |> assign(:editing_venue, nil)
     |> assign(:active_venue, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)
     |> assign(:form, empty_form())}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:venues, load_venues(socket))
     |> assign(:page_title, "Venues")
     |> Navigation.assign(:venues, [Navigation.root(:venues)])}
  end

  @impl true
  def handle_event("new_venue", _, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, :venue)
     |> assign(:editing_venue, nil)
     |> assign(:form, empty_form())}
  end

  @impl true
  def handle_event("edit_venue", %{"id" => id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:active_modal, :venue)
     |> assign(:editing_venue, venue)
     |> assign(:form, venue_form(venue))}
  end

  @impl true
  def handle_event("delete_venue", %{"id" => id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == id))
    Operations.delete_venue!(venue, socket.assigns.opts)

    {:noreply,
     socket
     |> assign(:venues, load_venues(socket))
     |> put_flash(:info, "Venue deleted.")}
  end

  @impl true
  def handle_event("validate_venue", %{"venue" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "venue"))}
  end

  @impl true
  def handle_event("save_venue", %{"venue" => params}, socket) do
    result =
      if venue = socket.assigns.editing_venue do
        Operations.update_venue(venue, params, socket.assigns.opts)
      else
        Operations.create_venue(params, socket.assigns.opts)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:active_modal, nil)
         |> assign(:editing_venue, nil)
         |> assign(:venues, load_venues(socket))
         |> put_flash(:info, "Venue saved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save venue.")}
    end
  end

  @impl true
  def handle_event("new_location", %{"venue-id" => venue_id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == venue_id))

    {:noreply,
     socket
     |> assign(:active_modal, :location)
     |> assign(:active_venue, venue)
     |> assign(:location_action, :new)
     |> assign(:editing_location, nil)}
  end

  @impl true
  def handle_event("edit_location", %{"id" => loc_id, "venue-id" => venue_id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == venue_id))
    loc = venue && Enum.find(venue.storage_locations, &(&1.id == loc_id))

    case loc do
      nil ->
        {:noreply, put_flash(socket, :error, "Location not found.")}

      _ ->
        {:noreply,
         socket
         |> assign(:active_modal, :location)
         |> assign(:active_venue, venue)
         |> assign(:location_action, :edit)
         |> assign(:editing_location, loc)}
    end
  end

  @impl true
  def handle_event("delete_location", %{"id" => loc_id, "venue-id" => venue_id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == venue_id))
    loc = venue && Enum.find(venue.storage_locations, &(&1.id == loc_id))

    case loc do
      nil ->
        {:noreply, put_flash(socket, :error, "Location not found.")}

      _ ->
        Operations.delete_storage_location!(loc, socket.assigns.opts)

        {:noreply,
         socket
         |> assign(:venues, load_venues(socket))
         |> put_flash(:info, "Location deleted.")}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, nil)
     |> assign(:editing_venue, nil)
     |> assign(:active_venue, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)}
  end

  @impl true
  def handle_info({LocationForm, {:location_saved, _loc}}, socket) do
    {:noreply,
     socket
     |> assign(:venues, load_venues(socket))
     |> assign(:active_modal, nil)
     |> assign(:active_venue, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)
     |> put_flash(:info, "Location saved.")}
  end

  defp load_venues(socket) do
    o = socket.assigns.opts
    venues = Operations.list_venues!(o)
    Ash.load!(venues, :storage_locations, actor: o[:actor], tenant: o[:tenant])
  end

  defp empty_form, do: to_form(%{"name" => "", "address" => ""}, as: "venue")
  defp venue_form(v), do: to_form(%{"name" => v.name, "address" => v.address || ""}, as: "venue")

  defp opts(socket) do
    [actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id]
  end
end
