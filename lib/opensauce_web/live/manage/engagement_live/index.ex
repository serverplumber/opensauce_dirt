defmodule OpenSauceWeb.EngagementLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.CRM
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Engagements
      <:subtitle>All active and recent client engagements</:subtitle>
      <:actions>
        <.link patch={~p"/manage/engagements/new"}>
          <.button variant={:primary}>New Engagement</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="engagements"
      rows={@engagements}
      row_click={fn e -> JS.navigate(~p"/manage/customers/#{e.customer.reference}/engagements") end}
    >
      <:empty>
        <div class="py-6 text-center text-sm text-stone-500">No engagements yet.</div>
      </:empty>

      <:col :let={e} label="Customer">
        <div class="font-medium text-stone-900">{customer_name(e.customer)}</div>
        <div :if={e.garden} class="text-xs text-stone-500">{e.garden.name}</div>
      </:col>

      <:col :let={e} label="Scope">
        <span class="line-clamp-1 text-stone-700">{e.scope_description || "—"}</span>
      </:col>

      <:col :let={e} label="Term">
        {term_label(e)}
      </:col>

      <:col :let={e} label="Status">
        <.badge
          text={e.status}
          colors={[
            {:draft, "text-stone-600 bg-stone-100"},
            {:proposed, "text-blue-700 bg-blue-50"},
            {:signed, "text-indigo-700 bg-indigo-50"},
            {:in_progress, "text-amber-700 bg-amber-50"},
            {:completed, "text-green-700 bg-green-50"},
            {:cancelled, "text-stone-400 bg-stone-100"}
          ]}
        />
      </:col>

      <:action :let={e}>
        <.link
          navigate={~p"/manage/customers/#{e.customer.reference}/engagements"}
          class="text-sm text-stone-500 hover:text-stone-700"
        >
          View
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action == :new}
      id="new-engagement-modal"
      title="New Engagement"
      show
      on_cancel={JS.patch(~p"/manage/engagements")}
    >
      <.live_component
        module={OpenSauceWeb.EngagementLive.FormComponent}
        id={:new}
        engagement={nil}
        customer={nil}
        current_member={@current_member}
        patch={~p"/manage/engagements"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :engagements, load_engagements(socket))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> then(&Navigation.assign(&1, :engagements, [Navigation.root(:engagements)]))}
  end

  @impl true
  def handle_info({OpenSauceWeb.EngagementLive.FormComponent, {:saved, _engagement}}, socket) do
    {:noreply, assign(socket, :engagements, load_engagements(socket))}
  end

  defp load_engagements(socket) do
    member = socket.assigns.current_member

    CRM.list_engagements!(
      actor: member,
      tenant: member.organisation_id,
      load: [:garden, :customer]
    )
  end

  defp page_title(:new), do: "New Engagement"
  defp page_title(_), do: "Engagements"

  defp customer_name(%{company_name_nickname: n}) when is_binary(n) and n != "", do: n
  defp customer_name(%{first_name: f, last_name: l}), do: "#{f} #{l}"

  defp term_label(%{term_start: nil, term_end: nil}), do: "—"
  defp term_label(%{term_start: s, term_end: nil}), do: "from #{s}"
  defp term_label(%{term_start: nil, term_end: e}), do: "until #{e}"
  defp term_label(%{term_start: s, term_end: e}), do: "#{s} → #{e}"
end
