defmodule OpenSauceWeb.VenueLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Operations
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- header --%>
      <div style="padding:12px 16px 14px;">
        <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.03em;color:#F4EFE2;">
          Venues
        </h1>
        <p style="font-size:13px;color:#9A9384;margin-top:3px;">Production sites and storage spaces.</p>
      </div>

      <%!-- list --%>
      <div style="padding:0 16px 100px;">
        <p :if={@venues == []} style="font-size:13.5px;color:#6E675A;text-align:center;padding:40px 0;">
          No venues yet
        </p>

        <div :for={venue <- @venues} class="jcard" style="cursor:pointer;">
          <.link
            navigate={~p"/manage/venues/#{venue.id}"}
            style="display:flex;align-items:center;gap:12px;text-decoration:none;color:inherit;"
          >
            <div style="flex:1;min-width:0;">
              <div style="display:flex;align-items:center;gap:8px;">
                <p style="font-size:15px;font-weight:700;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  {venue.name}
                </p>
                <span
                  :if={venue.id == @organisation.head_office_venue_id}
                  style="background:rgba(84,181,126,0.15);color:#54B57E;font-size:11px;font-weight:700;padding:2px 8px;border-radius:99px;white-space:nowrap;flex-shrink:0;letter-spacing:0.04em;"
                >
                  HQ
                </span>
              </div>
              <p
                :if={venue.address}
                style="font-size:12.5px;color:#9A9384;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"
              >
                {venue.address}
              </p>
              <p style="font-size:12px;color:#6E675A;margin-top:3px;">
                {location_count_label(venue.storage_locations)}
              </p>
            </div>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style="color:#6E675A;flex:0 0 auto;">
              <path
                d="M9 18l6-6-6-6"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </.link>
        </div>
      </div>

      <%!-- FAB --%>
      <button class="fab" ontouchstart="" aria-label="New venue" phx-click="new_venue">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
          <path d="M12 5v14M5 12h14" stroke="#0C1F15" stroke-width="2.5" stroke-linecap="round" />
        </svg>
      </button>

      <%!-- new / edit venue modal --%>
      <.modal
        :if={@active_modal == :venue}
        id="venue-modal"
        show
        title={if @editing_venue, do: "Edit Venue", else: "New Venue"}
        on_cancel={JS.push("close_modal")}
      >
        <form
          id="venue-form"
          phx-change="validate_venue"
          phx-submit="save_venue"
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
      </.modal>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:opts, opts(socket))
     |> assign(:active_modal, nil)
     |> assign(:editing_venue, nil)
     |> assign(:form, empty_form())}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:venues, load_venues(socket))
     |> assign(:page_title, "Venues")
     |> assign(:main_bg, "bg-[#16140E]")
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
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, nil)
     |> assign(:editing_venue, nil)}
  end

  defp load_venues(socket) do
    o = socket.assigns.opts
    venues = Operations.list_venues!(o)
    Ash.load!(venues, :storage_locations, actor: o[:actor], tenant: o[:tenant])
  end

  defp empty_form, do: to_form(%{"name" => "", "address" => ""}, as: "venue")

  defp opts(socket) do
    [actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id]
  end

  defp location_count_label([]), do: "No storage locations"
  defp location_count_label([_]), do: "1 storage location"
  defp location_count_label(locs), do: "#{length(locs)} storage locations"
end
