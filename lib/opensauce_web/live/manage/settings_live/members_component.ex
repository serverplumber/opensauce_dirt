defmodule OpenSauceWeb.SettingsLive.MembersComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts
  alias OpenSauce.Accounts.Roles

  @role_colors [
    owner: "bg-purple-100 text-purple-700 border-purple-300",
    manager: "bg-indigo-100 text-indigo-700 border-indigo-300",
    staff: "bg-blue-100 text-blue-700 border-blue-300"
  ]

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:show_invite_modal, fn -> false end)
      |> assign_new(:show_edit_modal, fn -> false end)
      |> assign_new(:editing_member, fn -> nil end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Manage team members and their access roles.
        </:subtitle>
        Members
        <:actions>
          <.button
            :if={Roles.can_manage_members?(@current_member)}
            type="button"
            variant={:primary}
            phx-click="show_invite_modal"
            phx-target={@myself}
          >
            <.icon name="hero-plus" class="mr-2 -ml-1 h-4 w-4" /> Invite Member
          </.button>
        </:actions>
      </.header>

      <div class="rounded-md border border-gray-200 bg-white">
        <div class="p-4">
          <.table id="members" rows={@members} wrapper_class="mt-0">
            <:col :let={m} label="Email">{m.user.email}</:col>
            <:col :let={m} label="Title">{m.display_title}</:col>
            <:col :let={m} label="Role">
              <.badge text={m.role} colors={role_colors()} />
            </:col>
            <:action :let={m}>
              <.button
                :if={m.id != @current_member.id and Roles.can_manage_members?(@current_member)}
                size={:sm}
                variant={:secondary}
                phx-click={JS.push("show_edit_modal", value: %{id: m.id}, target: @myself)}
              >
                Edit
              </.button>
              <.button
                :if={m.id != @current_member.id and Roles.can_remove_member?(@current_member)}
                size={:sm}
                variant={:danger}
                phx-click={JS.push("remove_member", value: %{id: m.id}, target: @myself)}
                data-confirm="Remove this member? This cannot be undone."
              >
                Remove
              </.button>
            </:action>
            <:empty>
              <div class="py-6 text-center text-sm text-stone-500">
                No team members yet. Invite one using the button above.
              </div>
            </:empty>
          </.table>
        </div>
      </div>

      <.modal
        :if={@show_invite_modal}
        id="invite-member-modal"
        show
        title="Invite Member"
        description="Add a new team member by email"
        on_cancel={JS.push("hide_invite_modal", target: @myself)}
      >
        <.simple_form
          for={@invite_form}
          id="invite-member-form"
          phx-target={@myself}
          phx-change="validate_invite"
          phx-submit="invite_member"
        >
          <.input field={@invite_form[:email]} type="email" label="Email" placeholder="member@example.com" />
          <.input field={@invite_form[:display_title]} type="text" label="Title" placeholder="e.g. Pastry Chef" />
          <.input
            field={@invite_form[:role]}
            type="radiogroup"
            label="Role"
            options={role_options(@current_member)}
            value={@invite_form[:role].value || :staff}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Inviting...">Invite</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@show_edit_modal}
        id="edit-member-modal"
        show
        title="Edit Member"
        description={"Edit #{@editing_member && @editing_member.user.email}"}
        on_cancel={JS.push("hide_edit_modal", target: @myself)}
      >
        <.simple_form
          for={@edit_form}
          id="edit-member-form"
          phx-target={@myself}
          phx-change="validate_edit"
          phx-submit="update_member"
        >
          <.input field={@edit_form[:display_title]} type="text" label="Title" placeholder="e.g. Pastry Chef" />
          <.input
            field={@edit_form[:role]}
            type="radiogroup"
            label="Role"
            options={role_options(@current_member)}
            value={@edit_form[:role].value}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    members = load_members(assigns.current_member)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:members, members)
     |> assign(:show_invite_modal, false)
     |> assign(:show_edit_modal, false)
     |> assign(:editing_member, nil)
     |> assign(:invite_form, invite_form())
     |> assign(:edit_form, edit_form(%{role: :staff}))}
  end

  @impl true
  def handle_event("show_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: false, invite_form: invite_form())}
  end

  @impl true
  def handle_event("show_edit_modal", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:editing_member, member)
     |> assign(:edit_form, edit_form(member))}
  end

  @impl true
  def handle_event("hide_edit_modal", _, socket) do
    {:noreply, assign(socket, show_edit_modal: false, editing_member: nil)}
  end

  @impl true
  def handle_event("validate_invite", %{"invite" => params}, socket) do
    {:noreply, assign(socket, :invite_form, invite_form(params))}
  end

  @impl true
  def handle_event("validate_edit", %{"edit" => params}, socket) do
    {:noreply, assign(socket, :edit_form, edit_form(params))}
  end

  @impl true
  def handle_event("invite_member", %{"invite" => params}, socket) do
    actor = socket.assigns.current_member
    org_id = actor.organisation_id

    user_result =
      case Accounts.get_user_by_email(params["email"]) do
        {:ok, user} -> {:ok, user}
        _ -> Accounts.create_user(%{email: params["email"]}, authorize?: false)
      end

    result =
      with {:ok, user} <- user_result do
        Accounts.create_organisation_member(
          %{
            user_id: user.id,
            organisation_id: org_id,
            role: params["role"] || "staff",
            display_title: params["display_title"]
          },
          authorize?: false
        )
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, load_members(actor))
         |> assign(:show_invite_modal, false)
         |> assign(:invite_form, invite_form())
         |> put_flash(:info, "Member invited.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not invite member — that email may already belong to this organisation.")}
    end
  end

  @impl true
  def handle_event("update_member", %{"edit" => params}, socket) do
    actor = socket.assigns.current_member
    member = socket.assigns.editing_member

    case Accounts.update_organisation_member(member, %{role: params["role"], display_title: params["display_title"]}, authorize?: false) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, load_members(actor))
         |> assign(:show_edit_modal, false)
         |> assign(:editing_member, nil)
         |> put_flash(:info, "Member updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update member.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    actor = socket.assigns.current_member
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    case Accounts.delete_organisation_member(member, authorize?: false) do
      :ok ->
        {:noreply,
         socket
         |> assign(:members, load_members(actor))
         |> put_flash(:info, "Member removed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove member.")}
    end
  end

  defp load_members(member) do
    Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)
  end

  defp invite_form(params \\ %{}) do
    to_form(Map.merge(%{"email" => "", "display_title" => "", "role" => "staff"}, params), as: "invite")
  end

  defp edit_form(%{role: role, display_title: title}) do
    to_form(%{"role" => to_string(role), "display_title" => title || ""}, as: "edit")
  end

  defp edit_form(%{"role" => _} = params) do
    to_form(params, as: "edit")
  end

  defp edit_form(_) do
    to_form(%{"role" => "staff", "display_title" => ""}, as: "edit")
  end

  # Owners can assign any role; managers can only assign up to manager.
  defp role_options(actor) do
    roles = if Roles.can_promote_to_owner?(actor), do: [:owner, :manager, :staff], else: [:manager, :staff]
    Enum.map(roles, &{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp role_colors, do: @role_colors
end
