defmodule OpenSauceWeb.SettingsLive.OrgFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts.Roles

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form :if={Roles.owner?(@current_member)}
        for={@form}
        id="org-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <section
          id="organisation-settings"
          aria-labelledby="organisation-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="organisation-settings-title" class="text-base font-semibold text-stone-800">
              Organisation
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              Your organisation's display name and address.
            </p>
          </div>
          <div class="space-y-4 p-4">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Acme Nursery" />

            <.inputs_for :if={@form[:address].value} :let={f_addr} field={@form[:address]}>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <.input field={f_addr[:street]} type="text" label="Street" placeholder="123 Garden Way" />
                </div>
                <.input field={f_addr[:city]} type="text" label="City" />
                <.input field={f_addr[:province]} type="text" label="Province" />
                <.input field={f_addr[:zip]} type="text" label="Postal Code" />
                <.input field={f_addr[:country]} type="text" label="Country" />
              </div>
            </.inputs_for>
          </div>
        </section>

        <section
          id="currency-settings"
          aria-labelledby="currency-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="currency-settings-title" class="text-base font-semibold text-stone-800">
              Currency
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              Default currency used across invoices and reports.
            </p>
          </div>
          <div class="p-4">
            <.input
              field={@form[:currency]}
              type="select"
              options={[{"Canadian Dollar", :CAD}, {"US Dollar", :USD}, {"Euro", :EUR}]}
              label="Currency"
            />
          </div>
        </section>

        <section
          id="tax-settings"
          aria-labelledby="tax-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="tax-settings-title" class="text-base font-semibold text-stone-800">
              Tax &amp; Pricing
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              How tax is applied and the default rate. Rates are decimal, e.g. 0.21 for 21%.
            </p>
          </div>
          <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2">
            <.input
              field={@form[:tax_mode]}
              type="select"
              options={[
                {"Exclusive (add tax)", :exclusive},
                {"Inclusive (price includes tax)", :inclusive}
              ]}
              label="Tax mode"
            />
            <.input
              field={@form[:tax_rate]}
              type="number"
              step="0.001"
              min="0"
              label="Tax rate"
              placeholder="0.21"
            />
          </div>
        </section>

        <section
          id="email-sender-settings"
          aria-labelledby="email-sender-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="email-sender-settings-title" class="text-base font-semibold text-stone-800">
              Email Sender
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              Sender name and address used on outgoing emails from this organisation.
            </p>
          </div>
          <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2">
            <.input
              field={@form[:email_from_name]}
              type="text"
              label="Sender name"
              placeholder="Acme Nursery"
            />
            <.input
              field={@form[:email_from_address]}
              type="email"
              label="Sender email"
              placeholder="hello@example.com"
            />
          </div>
        </section>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Organisation</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    form =
      AshPhoenix.Form.for_update(assigns.organisation, :update,
        as: "organisation",
        actor: assigns.current_member,
        forms: [
          address: [
            data: assigns.organisation.address,
            resource: OpenSauce.CRM.Address,
            create_action: :create,
            update_action: :update
          ]
        ]
      )

    {:ok, socket |> assign(assigns) |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"organisation" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"organisation" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, organisation} ->
        notify_parent({:saved, organisation})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
