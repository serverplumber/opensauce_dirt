defmodule OpenSauceWeb.SettingsLive.OrgFormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.Accounts
  alias OpenSauce.Accounts.Roles
  alias OpenSauce.Operations

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Manager+ visible: Currency & Tax --%>
      <div :if={Roles.manager_or_above?(@current_member)} class="space-y-6">
        <section
          id="currency-settings"
          aria-labelledby="currency-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="currency-settings-title" class="text-base font-semibold text-stone-800">
              Currency &amp; Tax
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              Default currency and how tax is applied across invoices.
            </p>
          </div>
          <div class="p-4">
            <.simple_form
              for={@currency_form}
              id="currency-form"
              phx-target={@myself}
              phx-change="save_currency"
              phx-submit="save_currency"
            >
              <.input
                field={@currency_form[:currency]}
                type="select"
                options={[{"Canadian Dollar", :CAD}, {"US Dollar", :USD}, {"Euro", :EUR}]}
                label="Currency"
              />
            </.simple_form>
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
              Tax mode, labour overhead, and individual tax lines. Rates are decimal — e.g. 0.05 for 5%.
              Compound taxes are applied on top of the base price plus all prior simple taxes.
            </p>
          </div>

          <div class="border-b border-stone-200 p-4">
            <.simple_form
              for={@pricing_form}
              id="pricing-form"
              phx-target={@myself}
              phx-submit="save_pricing"
            >
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <.input
                  field={@pricing_form[:tax_mode]}
                  type="select"
                  options={[
                    {"Exclusive (add tax on top)", :exclusive},
                    {"Inclusive (price already includes tax)", :inclusive}
                  ]}
                  label="Tax mode"
                />
                <.input
                  field={@pricing_form[:labor_overhead_percent]}
                  type="number"
                  step="0.001"
                  min="0"
                  label="Labour overhead"
                  placeholder="0.15"
                />
                <.input
                  field={@pricing_form[:mileage_cost_per_km]}
                  type="number"
                  step="0.001"
                  min="0"
                  label="Mileage cost per km"
                  placeholder="0.61"
                />
              </div>
              <:actions>
                <.button variant={:secondary} phx-disable-with="Saving...">Save</.button>
              </:actions>
            </.simple_form>
          </div>

          <div class="divide-y divide-stone-100">
            <div
              :for={rate <- @tax_rates}
              class="flex items-center gap-3 px-4 py-3"
              id={"tax-rate-#{rate.id}"}
            >
              <div class="flex-1">
                <span class="text-sm font-medium text-stone-800">{rate.name}</span>
                <span :if={rate.is_compound} class="ml-2 text-xs text-stone-500">compound</span>
              </div>
              <span class="text-sm text-stone-600">
                {rate.rate |> Decimal.mult(100) |> Decimal.round(3) |> Decimal.normalize()}%
              </span>
              <button
                type="button"
                phx-click="delete_tax_rate"
                phx-value-id={rate.id}
                phx-target={@myself}
                class="text-stone-400 hover:text-red-500"
                aria-label={"Delete #{rate.name}"}
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>

            <div :if={@tax_rates == []} class="px-4 py-3 text-sm text-stone-400">
              No tax lines yet.
            </div>

            <div :if={length(@tax_rates) >= 2} class="flex items-center justify-between border-t border-stone-200 px-4 py-3">
              <span class="text-sm font-medium text-stone-700">Total</span>
              <span class="text-sm font-semibold text-stone-900">
                {total_tax_rate(@tax_rates) |> Decimal.mult(100) |> Decimal.round(4) |> Decimal.normalize()}%
              </span>
            </div>
          </div>

          <div class="border-t border-stone-200 p-4">
            <.simple_form
              for={@new_tax_rate_form}
              id="new-tax-rate-form"
              phx-target={@myself}
              phx-submit="add_tax_rate"
            >
              <div class="grid grid-cols-1 gap-3 sm:grid-cols-4">
                <div class="sm:col-span-2">
                  <.input field={@new_tax_rate_form[:name]} type="text" label="Name" placeholder="GST" />
                </div>
                <.input
                  field={@new_tax_rate_form[:rate]}
                  type="number"
                  step="0.001"
                  min="0"
                  label="Rate %"
                  placeholder="5"
                />
                <.input
                  field={@new_tax_rate_form[:position]}
                  type="number"
                  min="0"
                  label="Position"
                  placeholder="0"
                />
              </div>
              <div class="mt-2">
                <.input
                  field={@new_tax_rate_form[:is_compound]}
                  type="checkbox"
                  label="Compound (applied on base + prior simple taxes)"
                />
              </div>
              <:actions>
                <.button variant={:secondary}>Add Tax Line</.button>
              </:actions>
            </.simple_form>
          </div>
        </section>
      </div>

      <%!-- Owner only: identity, head office, email --%>
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
              Display name and address.
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
          id="head-office-settings"
          aria-labelledby="head-office-settings-title"
          class="rounded-lg border border-stone-200 bg-stone-50"
        >
          <div class="border-b border-stone-200 px-4 py-3">
            <h3 id="head-office-settings-title" class="text-base font-semibold text-stone-800">
              Head Office
            </h3>
            <p class="mt-1 text-sm text-stone-600">
              The venue that serves as the organisation's primary location.
            </p>
          </div>
          <div class="p-4">
            <.input
              field={@form[:head_office_venue_id]}
              type="select"
              label="Head Office venue"
              options={[{"— none —", ""}] ++ Enum.map(@venues, &{&1.name, &1.id})}
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

    tax_rates = load_tax_rates(assigns.current_member)
    venues = load_venues(assigns.current_member)

    currency_form =
      to_form(%{"currency" => assigns.organisation.currency}, as: "currency")

    pricing_form =
      to_form(%{
        "tax_mode" => assigns.organisation.tax_mode,
        "labor_overhead_percent" => assigns.organisation.labor_overhead_percent,
        "mileage_cost_per_km" => assigns.organisation.mileage_cost_per_km
      }, as: "pricing")

    new_tax_rate_form =
      AshPhoenix.Form.for_create(OpenSauce.Accounts.TaxRate, :create,
        as: "tax_rate",
        actor: assigns.current_member,
        tenant: assigns.current_member.organisation_id
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(:form, to_form(form))
      |> assign(:venues, venues)
      |> assign(:tax_rates, tax_rates)
      |> assign(:currency_form, currency_form)
      |> assign(:pricing_form, pricing_form)
      |> assign(:new_tax_rate_form, to_form(new_tax_rate_form))

    {:ok, socket}
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

  @impl true
  def handle_event("save_currency", %{"currency" => %{"currency" => currency}}, socket) do
    actor = socket.assigns.current_member

    case Ash.update(socket.assigns.organisation, %{currency: String.to_existing_atom(currency)},
           action: :update,
           actor: actor
         ) do
      {:ok, organisation} ->
        notify_parent({:saved, organisation})

        {:noreply,
         socket
         |> assign(:organisation, organisation)
         |> assign(:currency_form, to_form(%{"currency" => organisation.currency}, as: "currency"))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_pricing", %{"pricing" => params}, socket) do
    actor = socket.assigns.current_member

    case Ash.update(
           socket.assigns.organisation,
           %{
             tax_mode: String.to_existing_atom(params["tax_mode"]),
             labor_overhead_percent: params["labor_overhead_percent"],
             mileage_cost_per_km: params["mileage_cost_per_km"]
           },
           action: :update,
           actor: actor
         ) do
      {:ok, organisation} ->
        notify_parent({:saved, organisation})

        pricing_form =
          to_form(%{
            "tax_mode" => organisation.tax_mode,
            "labor_overhead_percent" => organisation.labor_overhead_percent,
            "mileage_cost_per_km" => organisation.mileage_cost_per_km
          }, as: "pricing")

        {:noreply, socket |> assign(:organisation, organisation) |> assign(:pricing_form, pricing_form)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_tax_rate", %{"tax_rate" => params}, socket) do
    params = Map.update(params, "rate", "0", fn pct ->
      pct |> Decimal.new() |> Decimal.div(100) |> to_string()
    end)

    case AshPhoenix.Form.submit(socket.assigns.new_tax_rate_form, params: params) do
      {:ok, _rate} ->
        tax_rates = load_tax_rates(socket.assigns.current_member)

        new_form =
          AshPhoenix.Form.for_create(OpenSauce.Accounts.TaxRate, :create,
            as: "tax_rate",
            actor: socket.assigns.current_member,
            tenant: socket.assigns.current_member.organisation_id
          )

        {:noreply,
         socket
         |> assign(:tax_rates, tax_rates)
         |> assign(:new_tax_rate_form, to_form(new_form))}

      {:error, form} ->
        {:noreply, assign(socket, :new_tax_rate_form, form)}
    end
  end

  @impl true
  def handle_event("delete_tax_rate", %{"id" => id}, socket) do
    actor = socket.assigns.current_member

    rate =
      Ash.get!(OpenSauce.Accounts.TaxRate, id,
        actor: actor,
        tenant: actor.organisation_id
      )

    Ash.destroy!(rate, actor: actor, tenant: actor.organisation_id)

    {:noreply, assign(socket, :tax_rates, load_tax_rates(actor))}
  end

  defp load_tax_rates(actor) do
    Accounts.list_tax_rates(actor: actor, tenant: actor.organisation_id)
    |> case do
      {:ok, rates} -> rates
      _ -> []
    end
  end

  defp load_venues(actor) do
    Operations.list_venues!(actor: actor, tenant: actor.organisation_id)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  # Compound taxes are applied on (base + sum of all simple taxes), so they
  # effectively cost more than their nominal rate against the original base.
  defp total_tax_rate(rates) do
    simple_sum =
      rates
      |> Enum.reject(& &1.is_compound)
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.rate))

    compound_sum =
      rates
      |> Enum.filter(& &1.is_compound)
      |> Enum.reduce(Decimal.new(0), fn rate, acc ->
        Decimal.add(acc, Decimal.mult(rate.rate, Decimal.add(1, simple_sum)))
      end)

    Decimal.add(simple_sum, compound_sum)
  end
end
