defmodule OpenSauceWeb.JobLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="job-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-4">
          <.input
            field={@form[:customer_id]}
            type="select"
            label="Customer"
            options={Enum.map(@customers, &{customer_label(&1), &1.id})}
            prompt="Select a customer"
          />

          <.input
            field={@form[:address_id]}
            type="select"
            label="Garden / Site"
            options={Enum.map(@addresses, &{address_label(&1), &1.id})}
            prompt="Select a site"
          />

          <.input
            field={@form[:service_type]}
            type="select"
            label="Service type"
            options={[
              {"Installation", :installation},
              {"Maintenance", :maintenance},
              {"Delivery", :delivery},
              {"Consultation", :consultation},
              {"Pruning", :pruning},
              {"Open garden", :open_garden},
              {"Winterize", :winterize_garden}
            ]}
            prompt="Select type"
          />

          <.input
            :if={@upstream_jobs != []}
            name="job[upstream_job_id]"
            id="job_upstream_job_id"
            type="select"
            label="Supplies from"
            options={Enum.map(@upstream_jobs, &{upstream_job_label(&1), &1.id})}
            prompt="Select job"
            value=""
          />

          <div class="flex gap-4">
            <div class="flex-1">
              <.input field={@form[:scheduled_at]} type="datetime-local" label="Scheduled" step="1800" />
            </div>
            <div class="w-32">
              <.input
                field={@form[:estimated_duration_minutes]}
                type="number"
                label="Duration (min)"
                min="0"
              />
            </div>
          </div>

          <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Schedule Job</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{job: job} = assigns, socket) do
    member = assigns.current_member

    customers =
      CRM.list_customers!(
        actor: member,
        tenant: member.organisation_id,
        load: [garden_addresses: [:short_address], indoor_addresses: [:short_address]]
      )

    customer_id = job && job.customer_id
    addresses = addresses_for_customer(customers, customer_id)

    form =
      if job do
        AshPhoenix.Form.for_update(job, :update,
          as: "job",
          actor: member,
          tenant: member.organisation_id
        )
      else
        AshPhoenix.Form.for_create(Orders.Job, :create,
          as: "job",
          actor: member,
          tenant: member.organisation_id
        )
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:customers, customers)
     |> assign(:addresses, addresses)
     |> assign(:upstream_jobs, [])
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    customer_id = params["customer_id"]
    addresses = addresses_for_customer(socket.assigns.customers, customer_id)

    upstream_jobs =
      if params["address_id"] not in [nil, ""] and params["service_type"] not in [nil, ""] do
        load_upstream_jobs(params["address_id"], socket.assigns.current_member)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:addresses, addresses)
     |> assign(:upstream_jobs, upstream_jobs)}
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    {upstream_job_id, job_params} = Map.pop(params, "upstream_job_id")

    case AshPhoenix.Form.submit(socket.assigns.form, params: job_params) do
      {:ok, job} ->
        move_materials_from_upstream(upstream_job_id, job, socket)
        notify_parent({:saved, job})

        {:noreply,
         socket
         |> put_flash(:info, "Job scheduled successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp move_materials_from_upstream(id, _job, _socket) when id in [nil, ""], do: :ok

  defp move_materials_from_upstream(upstream_job_id, job, socket) do
    member = socket.assigns.current_member

    upstream =
      Orders.get_job_by_id!(upstream_job_id,
        actor: member,
        tenant: member.organisation_id,
        load: [:materials]
      )

    Enum.each(upstream.materials, fn jm ->
      Orders.move_job_material!(jm, %{job_id: job.id},
        actor: member,
        tenant: member.organisation_id
      )
    end)
  end

  defp load_upstream_jobs(address_id, member) do
    Orders.list_jobs_at_address!(address_id,
      actor: member,
      tenant: member.organisation_id
    )
    |> Enum.filter(&(&1.materials != []))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp upstream_job_label(%{service_type: st, scheduled_at: nil}),
    do: Phoenix.Naming.humanize(st)

  defp upstream_job_label(%{service_type: st, scheduled_at: dt}),
    do: "#{Phoenix.Naming.humanize(st)} — #{Calendar.strftime(dt, "%b %-d, %Y")}"

  defp customer_label(c) do
    if c.company_name_nickname,
      do: "#{c.company_name_nickname} (#{c.first_name} #{c.last_name})",
      else: "#{c.first_name} #{c.last_name}"
  end

  defp address_label(addr) do
    type = if addr.is_indoor, do: "indoor", else: "garden"
    name = addr.name || "Unnamed #{type}"
    short = addr.short_address

    if short, do: "#{name} — #{short}", else: name
  end

  defp addresses_for_customer(customers, customer_id) when is_binary(customer_id) do
    case Enum.find(customers, &(&1.id == customer_id)) do
      nil -> []
      c -> c.garden_addresses ++ c.indoor_addresses
    end
  end

  defp addresses_for_customer(_, _), do: []
end
