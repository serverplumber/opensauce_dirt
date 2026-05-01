defmodule OpenSauceWeb.SettingsLive.MembersComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts
  alias OpenSauce.Accounts.OrganisationMember.Types.Role

  @role_colors [
    owner: "bg-purple-100 text-purple-700 border-purple-300",
    manager: "bg-indigo-100 text-indigo-700 border-indigo-300",
    staff: "bg-blue-100 text-blue-700 border-blue-300",
    readonly: "bg-stone-100 text-stone-700 border-stone-300"
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
          <.button type="button" variant={:primary} phx-click="show_invite_modal" phx-target={@myself}>
            <.icon name="hero-plus" class="mr-2 -ml-1 h-4 w-4" /> Invite Member
          </.button>
        </:actions>
      </.header>

      <div class="rounded-md border border-gray-200 bg-white">
        <div class="p-4">
          <.table id="members" rows={@members} wrapper_class="mt-0">
            <:col :let={m} label="Email">{m.user.email}</:col>
            <:col :let={m} label="Role">
              <.badge text={m.role} colors={role_colors()} />
            </:col>
            <:action :let={m}>
              <.button
                :if={m.id != @current_member.id}
                size={:sm}
                variant={:secondary}
                phx-click={JS.push("show_edit_modal", value: %{id: m.id}, target: @myself)}
              >
                Edit
              </.button>
              <.button
                :if={m.id != @current_member.id}
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
          <.input
            field={@invite_form[:role]}
            type="radiogroup"
            label="Role"
            options={role_options()}
            value={@invite_form[:role].value || :staff}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Sending...">Send Invite</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@show_edit_modal}
        id="edit-role-modal"
        show
        title="Edit Role"
        description={"Change role for #{@editing_member && @editing_member.user.email}"}
        on_cancel={JS.push("hide_edit_modal", target: @myself)}
      >
        <.simple_form
          for={@role_form}
          id="edit-role-form"
          phx-target={@myself}
          phx-change="validate_role"
          phx-submit="update_role"
        >
          <.input
            field={@role_form[:role]}
            type="radiogroup"
            label="Role"
            options={role_options()}
            value={@role_form[:role].value}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Updating...">Update Role</.button>
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
     |> assign(:role_form, role_form(:staff))}
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
    {:noreply, socket |> assign(:show_edit_modal, true) |> assign(:editing_member, member) |> assign(:role_form, role_form(member.role))}
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
  def handle_event("validate_role", %{"role_edit" => params}, socket) do
    {:noreply, assign(socket, :role_form, role_form(params["role"]))}
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
          %{user_id: user.id, organisation_id: org_id, role: params["role"] || "staff"},
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
         |> put_flash(:info, "Member invited successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to invite member. The email may already be in use.")}
    end
  end

  @impl true
  def handle_event("update_role", %{"role_edit" => params}, socket) do
    actor = socket.assigns.current_member
    member = socket.assigns.editing_member

    case Accounts.update_organisation_member(member, %{role: params["role"]}, authorize?: false) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, load_members(actor))
         |> assign(:show_edit_modal, false)
         |> assign(:editing_member, nil)
         |> put_flash(:info, "Role updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update role.")}
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
         |> put_flash(:info, "Member removed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member.")}
    end
  end

  defp load_members(member) do
    Accounts.list_members_for_organisation!(member.organisation_id, authorize?: false)
  end

  defp invite_form(params \\ %{}) do
    to_form(Map.merge(%{"email" => "", "role" => "staff"}, params), as: "invite")
  end

  defp role_form(role) do
    to_form(%{"role" => to_string(role)}, as: "role_edit")
  end

  defp role_options do
    Role.values() |> Enum.map(&{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp role_colors, do: @role_colors
end
