defmodule OpenSauceWeb.EngagementLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Storage

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <.form for={@form} id="engagement-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div style="display:flex;flex-direction:column;gap:20px;padding:4px 0 0;">

          <%!-- customer — standalone only --%>
          <div :if={@standalone}>
            <label class="dark-label" for="engagement_customer_id">Customer</label>
            <select class="dark-select" name="engagement[customer_id]" id="engagement_customer_id">
              <option value="">Select a customer</option>
              <option :for={c <- @customers} value={c.id} selected={@customer_id == c.id}>
                {customer_label(c)}
              </option>
            </select>
          </div>

          <%!-- garden --%>
          <div>
            <label class="dark-label" for={@form[:garden_id].id}>Garden</label>
            <select class="dark-select" name={@form[:garden_id].name} id={@form[:garden_id].id}>
              <option value="">— none —</option>
              <option
                :for={g <- @gardens}
                value={g.id}
                selected={to_string(@form[:garden_id].value) == g.id}
              >
                {garden_label(g)}
              </option>
            </select>
          </div>

          <%!-- title --%>
          <div>
            <label class="dark-label" for={@form[:scope_title].id}>Title</label>
            <input
              class="dark-input"
              type="text"
              name={@form[:scope_title].name}
              id={@form[:scope_title].id}
              value={@form[:scope_title].value || ""}
              placeholder="e.g. Spring install — front garden"
            />
          </div>

          <%!-- scope --%>
          <div>
            <label class="dark-label" for={@form[:scope_description].id}>Scope</label>
            <textarea
              class="dark-textarea"
              name={@form[:scope_description].name}
              id={@form[:scope_description].id}
              rows="4"
            ><%= Phoenix.HTML.Form.normalize_value("textarea", @form[:scope_description].value) %></textarea>
          </div>

          <%!-- photos --%>
          <div>
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
              <span class="dark-label" style="margin-bottom:0;">Photos</span>
              <label for={@uploads.photos.ref} ontouchstart=""
                style="display:flex;align-items:center;gap:5px;font-size:12px;font-weight:700;color:#54B57E;cursor:pointer;">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none">
                  <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  <circle cx="12" cy="13" r="4" stroke="currentColor" stroke-width="2"/>
                </svg>
                Add
              </label>
            </div>
            <.live_file_input upload={@uploads.photos} style="display:none;" />
            <p :for={err <- upload_errors(@uploads.photos)} class="dark-field-error" style="margin-bottom:6px;">
              {upload_error_to_string(err)}
            </p>
            <div :if={@uploads.photos.entries != [] or @existing_photos != []}
              style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px;">
              <div :for={entry <- @uploads.photos.entries}
                style="position:relative;border-radius:8px;overflow:hidden;background:#211E16;aspect-ratio:1;">
                <.live_img_preview entry={entry} style="width:100%;height:100%;object-fit:cover;" />
                <div style="position:absolute;inset:0;display:flex;align-items:flex-start;justify-content:flex-end;padding:4px;">
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-target={@myself}
                    style="background:rgba(0,0,0,0.6);border:none;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#F4EFE2;font-size:11px;line-height:0;padding:0;">
                    ✕
                  </button>
                </div>
                <div :if={entry.progress > 0 and entry.progress < 100}
                  style={"position:absolute;bottom:0;left:0;height:3px;background:#54B57E;transition:width .1s;width:#{entry.progress}%;"}>
                </div>
              </div>
              <div :for={img <- @existing_photos}
                style="position:relative;border-radius:8px;overflow:hidden;background:#211E16;aspect-ratio:1;">
                <img src={Storage.url(img.storage_key)} style="width:100%;height:100%;object-fit:cover;" />
                <div style="position:absolute;inset:0;display:flex;align-items:flex-start;justify-content:flex-end;padding:4px;">
                  <button type="button" phx-click="delete_image" phx-value-id={img.id} phx-target={@myself}
                    style="background:rgba(0,0,0,0.6);border:none;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#F4EFE2;font-size:11px;line-height:0;padding:0;">
                    ✕
                  </button>
                </div>
              </div>
            </div>
            <div :if={@uploads.photos.entries == [] and @existing_photos == []}
              style="border-radius:12px;border:1.5px dashed rgba(52,48,37,0.58);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
              No photos yet
            </div>
          </div>

          <%!-- pricing --%>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div>
              <label class="dark-label" for={@form[:install_price].id}>Install</label>
              <div style="position:relative;">
                <span style="position:absolute;left:12px;top:50%;transform:translateY(-50%);font-size:14px;color:#9A9384;pointer-events:none;">
                  {currency_symbol(@currency)}
                </span>
                <input
                  class="dark-input"
                  type="number"
                  step="0.01"
                  min="0"
                  style="padding-left:26px;"
                  name={@form[:install_price].name}
                  id={@form[:install_price].id}
                  value={@form[:install_price].value}
                />
              </div>
            </div>
            <div>
              <label class="dark-label" for={@form[:maintenance_price_annual].id}>Maintenance</label>
              <div style="position:relative;">
                <span style="position:absolute;left:12px;top:50%;transform:translateY(-50%);font-size:14px;color:#9A9384;pointer-events:none;">
                  {currency_symbol(@currency)}
                </span>
                <input
                  class="dark-input"
                  type="number"
                  step="0.01"
                  min="0"
                  style="padding-left:26px;"
                  name={@form[:maintenance_price_annual].name}
                  id={@form[:maintenance_price_annual].id}
                  value={@form[:maintenance_price_annual].value}
                />
              </div>
            </div>
          </div>

          <%!-- term --%>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div>
              <label class="dark-label" for={@form[:term_start].id}>Term start</label>
              <input
                class="dark-input"
                type="date"
                name={@form[:term_start].name}
                id={@form[:term_start].id}
                value={Phoenix.HTML.Form.normalize_value("date", @form[:term_start].value)}
              />
            </div>
            <div>
              <label class="dark-label" for={@form[:term_end].id}>Term end</label>
              <input
                class="dark-input"
                type="date"
                name={@form[:term_end].name}
                id={@form[:term_end].id}
                value={Phoenix.HTML.Form.normalize_value("date", @form[:term_end].value)}
              />
            </div>
          </div>

          <%!-- status --%>
          <div>
            <label class="dark-label" for={@form[:status].id}>Status</label>
            <select class="dark-select" name={@form[:status].name} id={@form[:status].id}>
              <option :for={{label, val} <- status_options()} value={val}
                selected={to_string(@form[:status].value) == to_string(val)}>
                {label}
              </option>
            </select>
            <span :for={msg <- @form[:status].errors} class="dark-field-error">{elem(msg, 0)}</span>
          </div>

          <%!-- submit --%>
          <div style="padding-top:4px;">
            <.glow_button
              valid={form_valid?(@form, @standalone, @customer_id)}
              type="submit"
              phx-disable-with="Saving…"
            >
              {if @engagement, do: "Save changes", else: "Create engagement"}
            </.glow_button>
          </div>

        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{engagement: engagement, customer: customer} = assigns, socket) do
    member = assigns.current_member
    standalone = is_nil(customer)

    {customer_id, gardens, customers} =
      if standalone do
        all = load_customers(member)
        {"", [], all}
      else
        {customer.id, customer.garden_addresses, []}
      end

    form =
      if engagement do
        AshPhoenix.Form.for_update(engagement, :update,
          as: "engagement",
          actor: member,
          tenant: member.organisation_id
        )
      else
        AshPhoenix.Form.for_create(CRM.Engagement, :create,
          as: "engagement",
          actor: member,
          tenant: member.organisation_id
        )
      end

    socket =
      if socket.assigns[:_upload_init] do
        socket
      else
        socket
        |> allow_upload(:photos,
          accept: ~w(image/*),
          max_entries: 20,
          max_file_size: 20_000_000
        )
        |> assign(:_upload_init, true)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:existing_photos, fn -> load_existing_photos(engagement, member) end)
     |> assign(:standalone, standalone)
     |> assign(:customer_id, customer_id)
     |> assign(:customers, customers)
     |> assign(:gardens, gardens)
     |> assign(:currency, Map.get(assigns, :currency, :CAD))
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"engagement" => params}, socket) do
    {customer_id, gardens} =
      if socket.assigns.standalone do
        new_customer_id = params["customer_id"] || ""

        if new_customer_id != socket.assigns.customer_id and new_customer_id != "" do
          gardens = load_gardens(new_customer_id, socket.assigns.current_member)
          {new_customer_id, gardens}
        else
          {new_customer_id, socket.assigns.gardens}
        end
      else
        {socket.assigns.customer_id, socket.assigns.gardens}
      end

    params = Map.put(params, "customer_id", customer_id)
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:customer_id, customer_id)
     |> assign(:gardens, gardens)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("delete_image", %{"id" => id}, socket) do
    member = socket.assigns.current_member

    case Ash.get(CRM.EngagementImage, id,
           actor: member,
           tenant: member.organisation_id
         ) do
      {:ok, image} ->
        Storage.delete(image.storage_key)
        Ash.destroy!(image, actor: member, tenant: member.organisation_id)
        remaining = Enum.reject(socket.assigns.existing_photos, &(&1.id == id))
        {:noreply, assign(socket, :existing_photos, remaining)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save", %{"engagement" => params}, socket) do
    customer_id =
      if socket.assigns.standalone,
        do: params["customer_id"] || socket.assigns.customer_id,
        else: socket.assigns.customer_id

    params = Map.put(params, "customer_id", customer_id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, engagement} ->
        socket = process_uploads(socket, engagement)

        case Map.get(socket.assigns, :navigate) do
          dest when is_binary(dest) ->
            notify_parent({:saved_navigate, engagement, dest})
            {:noreply, socket}

          _ ->
            notify_parent({:saved, engagement})

            {:noreply,
             socket
             |> put_flash(:info, "Engagement saved.")
             |> push_patch(to: socket.assigns.patch)}
        end

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp process_uploads(socket, engagement) do
    entries = socket.assigns.uploads.photos.entries

    if entries == [] do
      socket
    else
      member = socket.assigns.current_member

      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        with {:ok, binary} <- File.read(path),
             {:ok, key} <-
               Storage.put(
                 "engagements/#{engagement.id}",
                 entry.client_name,
                 entry.client_type,
                 binary
               ) do
          CRM.create_engagement_image!(%{
            engagement_id: engagement.id,
            type: :photo,
            captured_on: Date.utc_today(),
            storage_key: key,
            content_type: entry.client_type,
            original_filename: entry.client_name
          },
            actor: member,
            tenant: member.organisation_id
          )

          {:ok, key}
        else
          _ -> {:ok, :skip}
        end
      end)

      socket
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp form_valid?(form, standalone, customer_id) do
    title_set? = form[:scope_title].value not in [nil, ""]
    garden_set? = form[:garden_id].value not in [nil, ""]
    scope_set? = form[:scope_description].value not in [nil, ""]
    term_set? = form[:term_start].value not in [nil, ""]
    customer_set? = not standalone or customer_id != ""

    title_set? and garden_set? and scope_set? and term_set? and customer_set?
  end

  defp status_options do
    [
      {"Draft", :draft},
      {"Proposed", :proposed},
      {"Signed", :signed},
      {"In progress", :in_progress},
      {"Completed", :completed},
      {"Cancelled", :cancelled}
    ]
  end

  defp currency_symbol(:CAD), do: "$"
  defp currency_symbol(:USD), do: "$"
  defp currency_symbol(:EUR), do: "€"
  defp currency_symbol(:GBP), do: "£"
  defp currency_symbol(_), do: "$"

  defp upload_error_to_string(:too_large), do: "File too large (max 20 MB)"
  defp upload_error_to_string(:not_accepted), do: "Only images are accepted"
  defp upload_error_to_string(:too_many_files), do: "Too many files (max 20)"
  defp upload_error_to_string(err), do: to_string(err)

  defp load_existing_photos(nil, _member), do: []

  defp load_existing_photos(engagement, member) do
    CRM.EngagementImage
    |> Ash.Query.for_read(:for_engagement, %{engagement_id: engagement.id})
    |> Ash.read!(actor: member, tenant: member.organisation_id)
  rescue
    _ -> []
  end

  defp load_customers(member) do
    CRM.list_customers!(actor: member, tenant: member.organisation_id)
  rescue
    _ -> []
  end

  defp load_gardens(customer_id, member) do
    case CRM.get_customer_by_id(customer_id,
           actor: member,
           tenant: member.organisation_id,
           load: [:street, :city, :name]
         ) do
      {:ok, customer} -> customer.garden_addresses
      _ -> []
    end
  end

  defp customer_label(c) do
    if c.company_name_nickname,
      do: "#{c.company_name_nickname} (#{c.first_name} #{c.last_name})",
      else: "#{c.first_name} #{c.last_name}"
  end

  defp garden_label(addr) do
    name = addr.name || "Garden"
    short = [addr.street, addr.city] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
    if short != "", do: "#{name} — #{short}", else: name
  end
end
