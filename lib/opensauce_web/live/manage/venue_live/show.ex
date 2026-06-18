defmodule OpenSauceWeb.VenueLive.Show do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts.Roles
  alias OpenSauce.Operations
  alias OpenSauceWeb.StorageLocationLive.FormComponent, as: LocationForm
  alias OpenSauceWeb.VenueLive.FormComponent, as: VenueForm

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- nav row --%>
      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px 0;">
        <.link navigate={~p"/manage/venues"}>
          <button
            type="button"
            style="color:#6E675A;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
            ontouchstart=""
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path
                d="M19 12H5M12 19l-7-7 7-7"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </button>
        </.link>
        <button
          type="button"
          style="font-size:13.5px;font-weight:700;color:#6E675A;background:none;border:none;cursor:pointer;padding:4px;"
          ontouchstart=""
          phx-click="edit_venue"
        >
          Edit
        </button>
      </div>

      <%!-- venue title --%>
      <div style="padding:14px 16px 20px;text-align:center;">
        <div style="display:flex;align-items:center;justify-content:center;gap:8px;">
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:26px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;margin:0;">
            {@venue.name}
          </h1>
          <span
            :if={@venue.id == @organisation.head_office_venue_id}
            style="background:rgba(84,181,126,0.15);color:#54B57E;font-size:11px;font-weight:700;padding:2px 8px;border-radius:99px;letter-spacing:0.04em;flex-shrink:0;"
          >
            HQ
          </span>
        </div>
        <p :if={@venue.address} style="font-size:13px;color:#9A9384;margin-top:6px;">{@venue.address}</p>
      </div>

      <div style="padding:0 16px 100px;display:flex;flex-direction:column;gap:12px;">

        <%!-- set head office (owners only, when not already HQ) --%>
        <button
          :if={Roles.owner?(@current_member) and @venue.id != @organisation.head_office_venue_id}
          type="button"
          ontouchstart=""
          phx-click="set_head_office"
          style="width:100%;border-radius:12px;background:rgba(84,181,126,0.08);border:1.5px solid rgba(84,181,126,0.25);padding:12px;font-size:13.5px;font-weight:700;color:#54B57E;cursor:pointer;"
        >
          Set as Head Office
        </button>

        <%!-- storage locations --%>
        <div style="background:#211E16;border:1.5px solid rgba(52,48,37,0.58);border-radius:16px;overflow:hidden;">
          <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <span style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;">
              Storage Locations
            </span>
            <button
              type="button"
              ontouchstart=""
              phx-click="new_location"
              style="display:flex;align-items:center;gap:4px;font-size:12px;font-weight:700;color:#54B57E;background:none;border:none;cursor:pointer;padding:0;"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" />
              </svg>
              Add
            </button>
          </div>

          <p
            :if={@storage_locations == []}
            style="font-size:13px;color:#6E675A;text-align:center;padding:20px 16px;"
          >
            No storage locations yet
          </p>

          <div
            :for={loc <- @storage_locations}
            style="display:flex;align-items:center;justify-content:space-between;padding:12px 16px;border-bottom:1px solid rgba(52,48,37,0.3);"
          >
            <span style="font-size:14px;color:#F4EFE2;">{loc.name}</span>
            <div style="display:flex;gap:8px;">
              <button
                type="button"
                ontouchstart=""
                phx-click="edit_location"
                phx-value-id={loc.id}
                style="font-size:12px;font-weight:700;color:#9A9384;background:none;border:none;cursor:pointer;padding:4px;"
              >
                Edit
              </button>
              <button
                type="button"
                ontouchstart=""
                phx-click="delete_location"
                phx-value-id={loc.id}
                style="font-size:12px;font-weight:700;color:#E87E7E;background:none;border:none;cursor:pointer;padding:4px;"
              >
                Delete
              </button>
            </div>
          </div>
        </div>

        <%!-- delete venue (owners only) --%>
        <button
          :if={Roles.owner?(@current_member)}
          type="button"
          ontouchstart=""
          phx-click="delete_venue"
          style="width:100%;border-radius:12px;background:transparent;border:1.5px solid rgba(232,126,126,0.25);padding:12px;font-size:13.5px;font-weight:700;color:#E87E7E;cursor:pointer;margin-top:8px;"
        >
          Delete Venue
        </button>
      </div>

      <%!-- edit venue modal --%>
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

      <%!-- location modal --%>
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
          venue={@venue}
          opts={@opts}
        />
      </.modal>
    </div>
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
     |> assign(:editing_location, nil)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, socket.assigns.venue.name)
     |> assign(:main_bg, "bg-[#16140E]")}
  end

  @impl true
  def handle_event("edit_venue", _, socket),
    do: {:noreply, assign(socket, :active_modal, :venue)}

  @impl true
  def handle_event("set_head_office", _, socket) do
    org = socket.assigns.organisation
    actor = socket.assigns.current_member

    case Ash.update(org, %{head_office_venue_id: socket.assigns.venue.id}, action: :update, actor: actor) do
      {:ok, updated_org} ->
        {:noreply, socket |> assign(:organisation, updated_org) |> put_flash(:info, "Head office updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update head office.")}
    end
  end

  @impl true
  def handle_event("delete_venue", _, socket) do
    Operations.delete_venue!(socket.assigns.venue, socket.assigns.opts)
    {:noreply, socket |> push_navigate(to: ~p"/manage/venues") |> put_flash(:info, "Venue deleted.")}
  end

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
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, nil)
     |> assign(:location_action, nil)
     |> assign(:editing_location, nil)}
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
    locations = Operations.list_storage_locations_for_venue!(socket.assigns.venue.id, socket.assigns.opts)
    assign(socket, :storage_locations, locations)
  end

  defp build_opts(socket) do
    member = socket.assigns.current_member
    [actor: member, tenant: member.organisation_id]
  end
end
