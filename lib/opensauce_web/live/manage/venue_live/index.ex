defmodule OpenSauceWeb.VenueLive.Index do
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
        <:subtitle>Production sites and storage spaces.</:subtitle>
        Venues
        <:actions>
          <.button variant={:primary} phx-click="new">
            <.icon name="hero-plus" class="-ml-1 mr-2 h-4 w-4" /> New Venue
          </.button>
        </:actions>
      </.header>

      <div class="rounded-md border border-gray-200 bg-white">
        <.table id="venues" rows={@venues}>
          <:col :let={v} label="Name">
            <.link navigate={~p"/manage/venues/#{v.id}"} class="font-medium text-stone-900 hover:underline">
              {v.name}
            </.link>
          </:col>
          <:col :let={v} label="Address">{v.address}</:col>
          <:action :let={v}>
            <.button size={:sm} variant={:secondary} phx-click="edit" phx-value-id={v.id}>
              Edit
            </.button>
            <.button
              size={:sm}
              variant={:danger}
              phx-click="delete"
              phx-value-id={v.id}
              data-confirm={"Delete #{v.name}? This cannot be undone."}
            >
              Delete
            </.button>
          </:action>
          <:empty>
            <div class="py-6 text-center text-sm text-stone-500">
              No venues yet. Add one to start tracking storage locations.
            </div>
          </:empty>
        </.table>
      </div>

      <.modal
        :if={@show_modal}
        id="venue-modal"
        show
        title={if @editing_venue, do: "Edit Venue", else: "New Venue"}
        on_cancel={JS.push("close_modal")}
      >
        <.simple_form for={@form} id="venue-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" placeholder="Main Kitchen" />
          <.input field={@form[:address]} type="text" label="Address" placeholder="123 Baker St" />
          <:actions>
            <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_modal, false)
     |> assign(:editing_venue, nil)
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
  def handle_event("new", _, socket) do
    {:noreply, socket |> assign(:show_modal, true) |> assign(:editing_venue, nil) |> assign(:form, empty_form())}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == id))
    {:noreply, socket |> assign(:show_modal, true) |> assign(:editing_venue, venue) |> assign(:form, venue_form(venue))}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, editing_venue: nil)}
  end

  @impl true
  def handle_event("validate", %{"venue" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "venue"))}
  end

  @impl true
  def handle_event("save", %{"venue" => params}, socket) do
    result =
      if venue = socket.assigns.editing_venue do
        Operations.update_venue(venue, params, opts(socket))
      else
        Operations.create_venue(params, opts(socket))
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_modal, false)
         |> assign(:editing_venue, nil)
         |> assign(:venues, load_venues(socket))
         |> put_flash(:info, "Venue saved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save venue.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    venue = Enum.find(socket.assigns.venues, &(&1.id == id))
    Operations.delete_venue!(venue, opts(socket))

    {:noreply,
     socket
     |> assign(:venues, load_venues(socket))
     |> put_flash(:info, "Venue deleted.")}
  end

  defp load_venues(socket), do: Operations.list_venues!(opts(socket))

  defp empty_form, do: to_form(%{"name" => "", "address" => ""}, as: "venue")
  defp venue_form(v), do: to_form(%{"name" => v.name, "address" => v.address || ""}, as: "venue")

  defp opts(socket) do
    [actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id]
  end
end
