defmodule OpenSauceWeb.EngagementLive.FormComponent do
  @moduledoc false
  use OpenSauceWeb, :live_component

  alias OpenSauce.CRM
  alias OpenSauce.Storage
  alias OpenSauceWeb.HtmlHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">

      <%!-- SIGNED: read-only scope + photo management only --%>
      <div :if={@signed?} style="display:flex;flex-direction:column;gap:20px;padding:4px 0 0;">

        <%!-- locked notice --%>
        <div style="display:flex;align-items:center;gap:8px;padding:10px 12px;background:rgba(84,181,126,0.07);border:1px solid rgba(84,181,126,0.2);border-radius:10px;">
          <span style="color:#54B57E;font-size:14px;line-height:1;">✓</span>
          <p style="font-size:12px;color:#54B57E;line-height:1.4;">
            Signed {signature_label_text(@engagement.signature)} — scope is locked
          </p>
        </div>

        <%!-- static scope --%>
        <div :if={@engagement.scope_title} style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px 14px;">
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:4px;">Title</p>
          <p style="font-size:14px;color:#F4EFE2;">{@engagement.scope_title}</p>
        </div>

        <div :if={@engagement.scope_description} style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:12px 14px;">
          <p style="font-size:10.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#6E675A;margin-bottom:4px;">Scope</p>
          <p style="font-size:13px;color:#F4EFE2;line-height:1.55;">{@engagement.scope_description}</p>
        </div>

        <%!-- pricing read-only --%>
        <div :if={@engagement.install_price || @engagement.maintenance_price_annual}
          style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
          <div :if={@engagement.install_price} style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;">
            <p style="font-size:10px;color:#6E675A;margin-bottom:3px;">Install</p>
            <p style="font-size:16px;font-weight:700;color:#F4EFE2;">{HtmlHelpers.format_currency(@currency, @engagement.install_price)}</p>
          </div>
          <div :if={@engagement.maintenance_price_annual} style="background:#211E16;border-radius:12px;border:1px solid rgba(52,48,37,0.58);padding:10px 12px;">
            <p style="font-size:10px;color:#6E675A;margin-bottom:3px;">Maintenance / yr</p>
            <p style="font-size:16px;font-weight:700;color:#F4EFE2;">{HtmlHelpers.format_currency(@currency, @engagement.maintenance_price_annual)}</p>
          </div>
        </div>

        <%!-- digital renderings: read-only --%>
        <div :if={@existing_paintings != []}>
          <span class="dark-label" style="margin-bottom:6px;display:block;color:#54B57E;">Digital Renderings</span>
          <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:8px;">
            <div :for={img <- @existing_paintings}
              style="position:relative;border-radius:8px;overflow:hidden;background:#211E16;aspect-ratio:3/4;border:1.5px solid rgba(84,181,126,0.35);">
              <img src={HtmlHelpers.storage_url(img.storage_key)} style="width:100%;height:100%;object-fit:cover;" />
            </div>
          </div>
        </div>

        <%!-- photos: still editable after signing --%>
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
                <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="photos" phx-target={@myself}
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
              <img src={HtmlHelpers.storage_url(img.storage_key)} style="width:100%;height:100%;object-fit:cover;" />
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

        <div :if={@uploads.photos.entries != []} style="padding-top:4px;">
          <.glow_button valid={true} type="button" phx-click="save_photos" phx-target={@myself} phx-disable-with="Saving…">
            Save photos
          </.glow_button>
        </div>

      </div>

      <%!-- UNSIGNED: full editable form --%>
      <.form :if={not @signed?} for={@form} id="engagement-form" phx-target={@myself} phx-change="validate" phx-submit="save">
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

          <%!-- digital renderings (paintings) — these are the contract images --%>
          <div>
            <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:6px;gap:8px;">
              <div style="flex:1;min-width:0;">
                <span class="dark-label" style="margin-bottom:2px;color:#54B57E;">Digital Renderings</span>
                <p style="font-size:11px;color:#6E675A;line-height:1.4;margin-top:2px;">
                  The visual scope the client signs off on. An engagement with a rendering uses "Garden as drawn" on invoices — without one it reads "Garden as described".
                </p>
              </div>
              <label for={@uploads.paintings.ref} ontouchstart=""
                style="display:flex;align-items:center;gap:5px;font-size:12px;font-weight:700;color:#54B57E;cursor:pointer;flex-shrink:0;padding-top:1px;">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none">
                  <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  <circle cx="12" cy="13" r="4" stroke="currentColor" stroke-width="2"/>
                </svg>
                Add
              </label>
            </div>
            <.live_file_input upload={@uploads.paintings} style="display:none;" />
            <p :for={err <- upload_errors(@uploads.paintings)} class="dark-field-error" style="margin-bottom:6px;">
              {upload_error_to_string(err)}
            </p>
            <div :if={@uploads.paintings.entries != [] or @existing_paintings != []}
              style="display:grid;grid-template-columns:repeat(2,1fr);gap:8px;">
              <div :for={entry <- @uploads.paintings.entries}
                style="position:relative;border-radius:8px;overflow:hidden;background:#211E16;aspect-ratio:3/4;border:1.5px solid rgba(84,181,126,0.35);">
                <.live_img_preview entry={entry} style="width:100%;height:100%;object-fit:cover;" />
                <div style="position:absolute;inset:0;display:flex;align-items:flex-start;justify-content:flex-end;padding:4px;">
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="paintings" phx-target={@myself}
                    style="background:rgba(0,0,0,0.6);border:none;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#F4EFE2;font-size:11px;line-height:0;padding:0;">
                    ✕
                  </button>
                </div>
                <div :if={entry.progress > 0 and entry.progress < 100}
                  style={"position:absolute;bottom:0;left:0;height:3px;background:#54B57E;transition:width .1s;width:#{entry.progress}%;"}>
                </div>
              </div>
              <div :for={img <- @existing_paintings}
                style="position:relative;border-radius:8px;overflow:hidden;background:#211E16;aspect-ratio:3/4;border:1.5px solid rgba(84,181,126,0.35);">
                <img src={HtmlHelpers.storage_url(img.storage_key)} style="width:100%;height:100%;object-fit:cover;" />
                <div style="position:absolute;inset:0;display:flex;align-items:flex-start;justify-content:flex-end;padding:4px;">
                  <button type="button" phx-click="delete_image" phx-value-id={img.id} phx-target={@myself}
                    style="background:rgba(0,0,0,0.6);border:none;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#F4EFE2;font-size:11px;line-height:0;padding:0;">
                    ✕
                  </button>
                </div>
              </div>
            </div>
            <div :if={@uploads.paintings.entries == [] and @existing_paintings == []}
              style="border-radius:12px;border:1.5px dashed rgba(84,181,126,0.25);padding:14px;font-size:13px;color:#6E675A;text-align:center;">
              No renderings yet — add one to define visual scope
            </div>
          </div>

          <%!-- photos — documentary, not contract items --%>
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
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="photos" phx-target={@myself}
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
                <img src={HtmlHelpers.storage_url(img.storage_key)} style="width:100%;height:100%;object-fit:cover;" />
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
        |> allow_upload(:paintings,
          accept: ~w(image/*),
          max_entries: 10,
          max_file_size: 20_000_000
        )
        |> assign(:_upload_init, true)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:existing_paintings, fn -> load_existing_paintings(engagement, member) end)
     |> assign_new(:existing_photos, fn -> load_existing_photos(engagement, member) end)
     |> assign(:signed?, engagement != nil && engagement.signature != nil)
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

  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload_name), ref)}
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

        socket =
          if image.type == :painting do
            remaining = Enum.reject(socket.assigns.existing_paintings, &(&1.id == id))
            assign(socket, :existing_paintings, remaining)
          else
            remaining = Enum.reject(socket.assigns.existing_photos, &(&1.id == id))
            assign(socket, :existing_photos, remaining)
          end

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save_photos", _params, socket) do
    socket = process_uploads(socket, socket.assigns.engagement)
    notify_parent({:saved, socket.assigns.engagement})
    {:noreply, socket}
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
    member = socket.assigns.current_member
    socket = consume_images(socket, :paintings, :painting, engagement, member)
    consume_images(socket, :photos, :photo, engagement, member)
  end

  defp consume_images(socket, upload_name, image_type, engagement, member) do
    if socket.assigns.uploads[upload_name].entries == [] do
      socket
    else
      consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
        with {:ok, binary} <- File.read(path),
             {:ok, key} <-
               Storage.put(
                 "engagements/#{engagement.id}",
                 entry.client_name,
                 entry.client_type,
                 binary
               ) do
          hash = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

          CRM.create_engagement_image!(%{
            engagement_id: engagement.id,
            type: image_type,
            captured_on: Date.utc_today(),
            storage_key: key,
            content_type: entry.client_type,
            original_filename: entry.client_name,
            content_hash: hash
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

  defp currency_symbol(:CAD), do: "$"
  defp currency_symbol(:USD), do: "$"
  defp currency_symbol(:EUR), do: "€"
  defp currency_symbol(:GBP), do: "£"
  defp currency_symbol(_), do: "$"

  defp upload_error_to_string(:too_large), do: "File too large (max 20 MB)"
  defp upload_error_to_string(:not_accepted), do: "Only images are accepted"
  defp upload_error_to_string(:too_many_files), do: "Too many files (max 10)"
  defp upload_error_to_string(err), do: to_string(err)

  defp load_existing_paintings(nil, _member), do: []

  defp load_existing_paintings(engagement, member) do
    CRM.list_engagement_paintings!(engagement.id,
      actor: member,
      tenant: member.organisation_id
    )
  rescue
    _ -> []
  end

  defp load_existing_photos(nil, _member), do: []

  defp load_existing_photos(engagement, member) do
    CRM.list_engagement_images!(engagement.id,
      actor: member,
      tenant: member.organisation_id
    )
    |> Enum.filter(&(&1.type == :photo))
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

  defp signature_label_text(%{signed_by_name: name, signed_at: at}) when is_binary(name) do
    date = if at, do: " · #{Calendar.strftime(at, "%d %b %Y")}", else: ""
    "by #{name}#{date}"
  end

  defp signature_label_text(_), do: ""

  defp garden_label(addr) do
    name = addr.name || "Garden"
    short = [addr.street, addr.city] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
    if short != "", do: "#{name} — #{short}", else: name
  end
end
