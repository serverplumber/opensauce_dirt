defmodule OpenSauceWeb.SettingsLive.Index do
  @moduledoc false
  use OpenSauceWeb, :live_view

  alias OpenSauce.Accounts
  alias OpenSauceWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <div class="mt-4 space-y-6">
      <div :if={@live_action in [:general, :index]}>
        <div class="flex flex-col gap-6 lg:flex-row">
          <div class="grow space-y-6">
            <div class="rounded-md border border-gray-200 bg-white p-6">
              <.live_component
                module={OpenSauceWeb.SettingsLive.OrgFormComponent}
                id="org-form"
                current_member={@current_member}
                organisation={@organisation}
              />
            </div>
          </div>

          <aside class="lg:w-64"></aside>
        </div>
      </div>

      <div :if={@live_action == :api_keys}>
        <div>
          <.live_component
            module={OpenSauceWeb.SettingsLive.ApiKeysComponent}
            id="api-keys-component"
            current_member={@current_member}
          />
        </div>
      </div>

      <div :if={@live_action == :calendar_feed}>
        <div>
          <.live_component
            module={OpenSauceWeb.SettingsLive.CalendarFeedComponent}
            id="calendar-feed-component"
            current_member={@current_member}
          />
        </div>
      </div>

      <div :if={@live_action == :members}>
        <div>
          <.live_component
            module={OpenSauceWeb.SettingsLive.MembersComponent}
            id="members-component"
            current_member={@current_member}
          />
        </div>
      </div>

      <div :if={@live_action == :csv} class="space-y-6">
        <.header>
          Import data into OpenSauce
          <:subtitle>
            Bring in your existing records. Each import walks you through column mapping so nothing gets lost.
          </:subtitle>
        </.header>
        <div class="flex flex-col gap-6 lg:flex-row">
          <section class="flex-1 rounded-md border border-gray-200 bg-white p-6">
            <div class="mt-6 space-y-4">
              <button
                :for={entity <- csv_import_entities()}
                type="button"
                class="w-full rounded-lg border border-stone-200 bg-stone-50 px-4 py-4 text-left transition hover:border-primary-400 hover:bg-white"
                phx-click="open_import"
                phx-value-entity={entity.value}
              >
                <div class="flex items-start gap-3">
                  <div class="text-primary-500 rounded-lg border border-stone-300 bg-white p-2">
                    <.icon name={entity.icon} class="h-5 w-5" />
                  </div>
                  <div class="flex-1">
                    <div class="flex items-center justify-between">
                      <span class="text-base font-medium text-stone-900">{entity.label}</span>
                      <span class="text-xs font-medium uppercase tracking-wide text-stone-500">
                        CSV
                      </span>
                    </div>
                    <p class="mt-1 text-sm text-stone-600">{entity.description}</p>
                    <p class="mt-2 text-xs text-stone-500">
                      Includes: {entity.includes}
                    </p>
                  </div>
                </div>
              </button>
            </div>

            <p class="mt-6 text-xs text-stone-500">
              Need a template first? Click an import to download the matching CSV header layout.
            </p>
          </section>

          <aside class="space-y-6 lg:w-96">
            <section class="rounded-md border border-gray-200 bg-white p-6">
              <h3 class="text-base font-semibold text-stone-900">Export data</h3>
              <p class="mt-1 text-sm text-stone-600">
                Generate a CSV extract for your reporting and accounting workflows.
              </p>

              <.form for={@csv_export_form} id="csv-export-form" phx-submit="csv_export">
                <div class="mt-4 space-y-4">
                  <.input
                    type="select"
                    name="entity"
                    label="Entity to export"
                    options={[
                      {"Customers", "customers"},
                      {"Inventory movements", "movements"}
                    ]}
                    value="customers"
                    required
                  />
                </div>
                <div class="mt-6 flex gap-2">
                  <.button id="csv-export-submit" variant={:primary} class="flex-1 justify-center">
                    Export CSV
                  </.button>
                </div>
              </.form>
            </section>

            <section class="border-primary-200 bg-primary-50 text-primary-800 rounded-md border border-dashed p-6 text-sm">
              <h4 class="text-primary-900 font-semibold">Tip</h4>
              <p class="mt-2">
                Keep a snapshot of your data by exporting on a schedule. Imports are idempotent—reimporting an updated CSV lets you keep OpenSauce and your spreadsheets in sync.
              </p>
            </section>
          </aside>
        </div>

        <.live_component
          module={OpenSauceWeb.ImportModalComponent}
          id="csv-mapping-modal"
          show={@show_mapping_modal}
          entity={@selected_entity}
          current_member={@current_member}
        />
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    organisation = Accounts.get_organisation!(socket.assigns.current_member.organisation_id, authorize?: false, load: [:address])

    socket =
      socket
      |> assign(:organisation, organisation)
      |> assign(:csv_form, to_form(%{}))
      |> assign(:csv_export_form, to_form(%{}))
      |> assign(:show_mapping_modal, false)
      |> assign(:selected_entity, nil)
      |> assign_new(:current_member, fn -> nil end)

    # Always configure CSV upload; harmless on other tabs and avoids missing @uploads
    socket =
      allow_upload(socket, :csv,
        accept: [".csv", "text/csv"],
        max_entries: 1
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    socket = apply_action(socket, live_action, params)

    {:noreply, Navigation.assign(socket, :settings, settings_trail(live_action))}
  end

  @impl true
  def handle_event("open_import", %{"entity" => entity}, socket) do
    {:noreply,
     socket
     |> assign(:selected_entity, entity)
     |> assign(:show_mapping_modal, true)}
  end

  def handle_event("csv_export", %{"entity" => entity}, socket) do
    {:noreply, redirect(socket, to: ~p"/manage/settings/csv/export/#{entity}")}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Organisation")
  end

  defp apply_action(socket, :general, _params) do
    assign(socket, :page_title, "Settings")
  end

  defp apply_action(socket, :csv, _params) do
    assign(socket, :page_title, "Import & Export")
  end

  defp apply_action(socket, :api_keys, _params) do
    assign(socket, :page_title, "API Keys")
  end

  defp apply_action(socket, :calendar_feed, _params) do
    assign(socket, :page_title, "Calendar Feed")
  end

  defp apply_action(socket, :members, _params) do
    assign(socket, :page_title, "Staff")
  end

  def csv_import_entities do
    [
      %{
        value: "materials",
        label: "Materials",
        icon: "hero-archive-box-solid",
        description: "Bulk load raw materials so inventory stays accurate.",
        includes: "Names, suppliers, units, cost"
      },
      %{
        value: "customers",
        label: "Customers",
        icon: "hero-user-group-solid",
        description: "Bring in customer records.",
        includes: "Names, company, contact details, delivery notes"
      }
    ]
  end

  defp settings_trail(:general), do: [Navigation.root(:settings), Navigation.page(:settings, :general)]

  defp settings_trail(:csv), do: [Navigation.root(:settings), Navigation.page(:settings, :csv)]

  defp settings_trail(:api_keys), do: [Navigation.root(:settings), Navigation.page(:settings, :api_keys)]

  defp settings_trail(:calendar_feed), do: [Navigation.root(:settings), Navigation.page(:settings, :calendar_feed)]

  defp settings_trail(:members), do: [Navigation.root(:settings), Navigation.page(:settings, :members)]

  defp settings_trail(_), do: [Navigation.root(:settings)]

  # Component close callback from ImportModalComponent
  @impl true
  def handle_info({:import_modal, :closed}, socket) do
    {:noreply, assign(socket, :show_mapping_modal, false)}
  end

  @impl true
  def handle_info({OpenSauceWeb.SettingsLive.OrgFormComponent, {:saved, organisation}}, socket) do
    {:noreply, socket |> assign(:organisation, organisation) |> put_flash(:info, "Organisation updated.")}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
