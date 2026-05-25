defmodule OpenSauceWeb.InventoryLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Inventory
  alias OpenSauceWeb.Components.Page
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <Page.page>
      <.header>
        Inventory
        <:subtitle>Materials, stock levels, and pricing.</:subtitle>
        <:actions>
          <.link patch={~p"/manage/inventory/new"}>
            <.button variant={:primary}>New Material</.button>
          </.link>
        </:actions>
      </.header>

      <Page.section>
        <Page.surface>
          <.table
            id="materials"
            rows={@streams.materials}
            row_id={fn {dom_id, _} -> dom_id end}
            row_click={fn {_, material} -> JS.navigate(~p"/manage/inventory/#{material.sku}") end}
          >
            <:empty>
              <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-10 text-center text-sm text-stone-500">
                No materials yet. Add your first to start tracking stock.
              </div>
            </:empty>
            <:col :let={{_, material}} label="Material">{material.name}</:col>
            <:col :let={{_, material}} label="SKU">
              <.kbd>{material.sku}</.kbd>
            </:col>
            <:col :let={{_, material}} label="Type">
              {material.material_type}
            </:col>
            <:col :let={{_, material}} label="Stock">
              {format_amount(material.unit, material.current_stock)}
            </:col>
            <:col :let={{_, material}} label="Price">
              {format_money(@organisation.currency, material.price)} / {material.unit}
            </:col>
            <:action :let={{_, material}}>
              <div class="sr-only">
                <.link navigate={~p"/manage/inventory/#{material.sku}"}>Show</.link>
              </div>
            </:action>
            <:action :let={{_, material}}>
              <.link phx-click={JS.push("delete", value: %{id: material.id}) |> hide("##{material.sku}")}>
                <.button size={:sm} variant={:danger}>Delete</.button>
              </.link>
            </:action>
          </.table>
        </Page.surface>
      </Page.section>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="material-modal"
        title={@page_title}
        show
        on_cancel={JS.patch(~p"/manage/inventory")}
      >
        <.live_component
          module={OpenSauceWeb.InventoryLive.FormComponentMaterial}
          id={(@material && @material.id) || :new}
          current_member={@current_member}
          title={@page_title}
          action={@live_action}
          material={@material}
          patch={~p"/manage/inventory"}
        />
      </.modal>
    </Page.page>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, Navigation.assign(socket, :inventory, inventory_trail(socket.assigns))}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Material")
    |> assign(:material, nil)
    |> load_materials()
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Inventory")
    |> assign(:material, nil)
    |> load_materials()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    member = socket.assigns.current_member

    material =
      Inventory.get_material_by_id!(id,
        load: [:current_stock],
        actor: member,
        tenant: member.organisation_id
      )

    socket
    |> assign(:page_title, "Edit Material")
    |> assign(:material, material)
    |> load_materials()
  end

  defp load_materials(socket) do
    member = socket.assigns.current_member

    materials =
      Inventory.list_materials!(
        actor: member,
        tenant: member.organisation_id,
        load: [:current_stock]
      )

    stream(socket, :materials, materials, reset: true)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    member = socket.assigns.current_member

    case id
         |> Inventory.get_material_by_id!(actor: member, tenant: member.organisation_id)
         |> Inventory.destroy_material(actor: member, tenant: member.organisation_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Material deleted.")
         |> stream_delete(:materials, %{id: id})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete material.")}
    end
  end

  @impl true
  def handle_info({:saved, material}, socket) do
    member = socket.assigns.current_member
    material = Ash.load!(material, :current_stock, actor: member, tenant: member.organisation_id)
    {:noreply, stream_insert(socket, :materials, material)}
  end

  defp inventory_trail(%{live_action: :new}),
    do: [Navigation.root(:inventory), Navigation.page(:inventory, :new_material)]

  defp inventory_trail(%{live_action: :edit, material: material}) when not is_nil(material),
    do: [Navigation.root(:inventory), Navigation.resource(:material, material)]

  defp inventory_trail(_), do: [Navigation.root(:inventory)]
end
