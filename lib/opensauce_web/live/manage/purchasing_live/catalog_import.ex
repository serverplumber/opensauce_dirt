defmodule OpenSauceWeb.PurchasingLive.CatalogImport do
  @moduledoc false
  use OpenSauceWeb, :live_view

  import Ash.Query

  alias OpenSauce.Inventory
  alias OpenSauce.Inventory.CatalogImporter
  alias OpenSauceWeb.Navigation

  @impl true
  def mount(%{"id" => supplier_id}, _session, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    supplier = Inventory.get_supplier_by_id!(supplier_id, opts)

    catalogs =
      Inventory.SupplierCatalog
      |> filter(supplier_id == ^supplier_id)
      |> Ash.Query.sort(year: :desc, name: :asc)
      |> Ash.read!(opts)

    socket =
      socket
      |> assign(:supplier, supplier)
      |> assign(:catalogs, catalogs)
      |> assign(:catalog_id, nil)
      |> assign(:preview, nil)
      |> assign(:extracting, false)
      |> assign(:result, nil)
      |> assign(:error, nil)
      |> assign(:show_new_catalog, false)
      |> assign(:json_files, json_files_in_catalog())
      |> allow_upload(:pdf,
        accept: [".pdf", "application/pdf"],
        max_entries: 1,
        max_file_size: 20_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Import Catalog")
     |> assign(:main_bg, "bg-[#16140E]")
     |> Navigation.assign(:purchasing, [
       Navigation.root(:purchasing),
       Navigation.page(:purchasing, :suppliers),
       Navigation.resource(:supplier, socket.assigns.supplier),
       %{label: "Import catalog", path: nil}
     ])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family:'Hanken Grotesk',system-ui,sans-serif;color:#F4EFE2;-webkit-font-smoothing:antialiased;">
      <%!-- header --%>
      <div style="padding:12px 16px 14px;display:flex;align-items:center;gap:10px;">
        <.link navigate={~p"/manage/purchasing/suppliers"}>
          <button
            type="button"
            ontouchstart=""
            style="color:#9A9384;background:none;border:none;padding:4px;cursor:pointer;line-height:0;"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </button>
        </.link>
        <div>
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:19px;font-weight:700;letter-spacing:-0.02em;color:#F4EFE2;">
            Import catalog
          </h1>
          <p style="font-size:12px;color:#6E675A;margin-top:1px;">{@supplier.name}</p>
        </div>
      </div>

      <div style="padding:0 16px 100px;display:flex;flex-direction:column;gap:14px;">
        <%!-- catalog selector --%>
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px;">
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            Catalog
          </p>

          <div style="display:flex;flex-direction:column;gap:6px;">
            <label
              :for={cat <- @catalogs}
              style={"display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;border:1px solid #{if @catalog_id == cat.id, do: "#54B57E", else: "rgba(52,48,37,0.58)"};background:#{if @catalog_id == cat.id, do: "rgba(84,181,126,0.08)", else: "transparent"};cursor:pointer;"}
            >
              <input
                type="radio"
                name="catalog_id"
                value={cat.id}
                checked={@catalog_id == cat.id}
                phx-click="select_catalog"
                phx-value-id={cat.id}
                style="accent-color:#54B57E;"
              />
              <span style="font-size:14px;font-weight:600;color:#F4EFE2;flex:1;">{cat.name}</span>
              <span style="font-size:12px;color:#6E675A;">{cat.year}</span>
            </label>
          </div>

          <div style="margin-top:10px;border-top:1px solid rgba(52,48,37,0.58);padding-top:10px;">
            <button
              :if={!@show_new_catalog}
              type="button"
              phx-click="toggle_new_catalog"
              ontouchstart=""
              style="font-size:13px;color:#54B57E;background:none;border:none;padding:0;cursor:pointer;"
            >
              + New catalog
            </button>

            <form :if={@show_new_catalog} phx-submit="create_catalog" style="display:flex;gap:8px;align-items:flex-end;">
              <div style="flex:1;">
                <label class="dark-label">Name</label>
                <input
                  class="dark-input"
                  type="text"
                  name="name"
                  placeholder="Spring 2026"
                  required
                />
              </div>
              <div style="width:80px;">
                <label class="dark-label">Year</label>
                <input
                  class="dark-input"
                  type="number"
                  name="year"
                  value={Date.utc_today().year}
                />
              </div>
              <button
                type="submit"
                ontouchstart=""
                style="height:42px;padding:0 14px;background:#54B57E;border:none;border-radius:10px;font-size:13px;font-weight:700;color:#0C1F15;cursor:pointer;flex-shrink:0;"
              >
                Create
              </button>
            </form>
          </div>
        </div>

        <%!-- PDF upload --%>
        <div style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px;">
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            PDF
          </p>

          <div
            style="border:2px dashed rgba(52,48,37,0.8);border-radius:12px;padding:28px 16px;text-align:center;"
            phx-drop-target={@uploads.pdf.ref}
          >
            <.live_file_input upload={@uploads.pdf} style="display:block;margin:0 auto 8px;font-size:13px;color:#9A9384;" />
            <p style="font-size:11px;color:#6E675A;">Max 20 MB · PDF only</p>

            <div :for={entry <- @uploads.pdf.entries} style="margin-top:12px;">
              <div style="display:flex;align-items:center;gap:10px;background:rgba(52,48,37,0.4);border-radius:10px;padding:8px 12px;">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6z" stroke="#9A9384" stroke-width="1.8" stroke-linecap="round" />
                </svg>
                <span style="flex:1;font-size:13px;color:#F4EFE2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{entry.client_name}</span>
                <span style="font-size:12px;color:#6E675A;flex-shrink:0;">{Float.round(entry.client_size / 1_000_000, 1)} MB</span>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  ontouchstart=""
                  style="color:#6E675A;background:none;border:none;padding:2px;cursor:pointer;line-height:0;"
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                    <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                  </svg>
                </button>
              </div>
              <p :for={err <- upload_errors(@uploads.pdf, entry)} style="font-size:12px;color:#E87E7E;margin-top:4px;">
                {upload_error_label(err)}
              </p>
            </div>
          </div>

          <div style="margin-top:12px;display:flex;justify-content:flex-end;">
            <button
              type="button"
              phx-click="extract"
              ontouchstart=""
              disabled={@uploads.pdf.entries == [] or is_nil(@catalog_id) or @extracting}
              style={"padding:10px 20px;border:none;border-radius:12px;font-size:14px;font-weight:700;cursor:pointer;#{if @uploads.pdf.entries == [] or is_nil(@catalog_id) or @extracting, do: "background:rgba(52,48,37,0.5);color:#6E675A;", else: "background:#54B57E;color:#0C1F15;"}"}
            >
              {if @extracting, do: "Extracting…", else: "Extract with Claude"}
            </button>
          </div>

          <div :if={@error} style="margin-top:10px;background:rgba(232,126,126,0.12);border-radius:10px;padding:10px 12px;">
            <p style="font-size:13px;color:#E87E7E;">{@error}</p>
          </div>
        </div>

        <%!-- JSON dev loader --%>
        <div :if={@json_files != []} style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;padding:14px;">
          <p style="font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;margin-bottom:10px;">
            Load from JSON
          </p>
          <div style="display:flex;flex-direction:column;gap:8px;">
            <div :for={path <- @json_files} style="display:flex;align-items:center;justify-content:space-between;gap:10px;">
              <span style="font-size:12px;font-family:monospace;color:#9A9384;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {Path.basename(path)}
              </span>
              <button
                type="button"
                phx-click="load_json"
                phx-value-path={path}
                ontouchstart=""
                disabled={is_nil(@catalog_id)}
                style={"flex-shrink:0;padding:6px 12px;border:1px solid rgba(52,48,37,0.58);border-radius:8px;font-size:12px;font-weight:600;cursor:pointer;#{if is_nil(@catalog_id), do: "background:transparent;color:#6E675A;", else: "background:rgba(52,48,37,0.5);color:#F4EFE2;"}"}
              >
                Load
              </button>
            </div>
          </div>
          <p :if={is_nil(@catalog_id)} style="font-size:12px;color:#6E675A;margin-top:8px;">
            Select a catalog above first.
          </p>
        </div>

        <%!-- preview table --%>
        <div :if={@preview} style="background:#211E16;border:1px solid rgba(52,48,37,0.58);border-radius:16px;overflow:hidden;">
          <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 14px;border-bottom:1px solid rgba(52,48,37,0.58);">
            <p style="font-size:14px;font-weight:700;color:#F4EFE2;">{length(@preview)} items extracted</p>
            <button
              type="button"
              phx-click="commit"
              ontouchstart=""
              style="background:#54B57E;border:none;border-radius:10px;padding:8px 16px;font-size:13px;font-weight:700;color:#0C1F15;cursor:pointer;"
            >
              Import all
            </button>
          </div>
          <div style="overflow-x:auto;">
            <table style="width:100%;border-collapse:collapse;font-size:12px;">
              <thead>
                <tr style="border-bottom:1px solid rgba(52,48,37,0.58);">
                  <th style="padding:8px 10px;text-align:left;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">SKU</th>
                  <th style="padding:8px 10px;text-align:left;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">Name</th>
                  <th style="padding:8px 10px;text-align:left;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">Latin name</th>
                  <th style="padding:8px 10px;text-align:left;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">Cultivar</th>
                  <th style="padding:8px 10px;text-align:left;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">Format</th>
                  <th style="padding:8px 10px;text-align:left;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">Cat.</th>
                  <th style="padding:8px 10px;text-align:right;font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:#6E675A;white-space:nowrap;">Price</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={item <- @preview}
                  style="border-bottom:1px solid rgba(52,48,37,0.3);"
                >
                  <td style="padding:7px 10px;font-family:monospace;font-size:11px;color:#9A9384;white-space:nowrap;">{item["sku"]}</td>
                  <td style="padding:7px 10px;color:#F4EFE2;white-space:nowrap;">{item["name"]}</td>
                  <td style="padding:7px 10px;font-style:italic;color:#9A9384;white-space:nowrap;">{item["latin_name"]}</td>
                  <td style="padding:7px 10px;color:#9A9384;white-space:nowrap;">{item["cultivar"]}</td>
                  <td style="padding:7px 10px;color:#6E675A;white-space:nowrap;">{item["format_description"]}</td>
                  <td style="padding:7px 10px;white-space:nowrap;">
                    <span style={"#{category_style(item["category"])}border-radius:8px;padding:2px 7px;font-size:10px;font-weight:700;"}>
                      {item["category"]}
                    </span>
                  </td>
                  <td style="padding:7px 10px;text-align:right;color:#F4EFE2;white-space:nowrap;">
                    {item["unit_price"] || "—"}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- result --%>
        <div :if={@result} style="background:rgba(84,181,126,0.12);border:1px solid rgba(84,181,126,0.3);border-radius:14px;padding:14px;">
          <p style="font-size:14px;font-weight:700;color:#54B57E;">
            Imported {@result.created} items.
          </p>
          <p :if={@result.failed > 0} style="font-size:13px;color:#DB9258;margin-top:4px;">
            {@result.failed} failed — check logs.
          </p>
          <.link navigate={~p"/manage/purchasing/suppliers"}>
            <button
              type="button"
              ontouchstart=""
              style="margin-top:10px;background:rgba(52,48,37,0.5);border:1px solid rgba(52,48,37,0.58);border-radius:10px;padding:8px 14px;font-size:13px;font-weight:600;color:#F4EFE2;cursor:pointer;"
            >
              ← Back to suppliers
            </button>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_catalog", %{"id" => id}, socket) do
    {:noreply, assign(socket, :catalog_id, id)}
  end

  @impl true
  def handle_event("toggle_new_catalog", _params, socket) do
    {:noreply, assign(socket, :show_new_catalog, !socket.assigns.show_new_catalog)}
  end

  @impl true
  def handle_event("create_catalog", %{"name" => name, "year" => year}, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    attrs = %{
      supplier_id: socket.assigns.supplier.id,
      name: String.trim(name),
      year: String.to_integer(year),
      season: :year_round
    }

    case Inventory.create_supplier_catalog(attrs, opts) do
      {:ok, cat} ->
        {:noreply,
         socket
         |> assign(:catalogs, [cat | socket.assigns.catalogs])
         |> assign(:catalog_id, cat.id)
         |> assign(:show_new_catalog, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create catalog.")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  @impl true
  def handle_event("extract", _params, socket) do
    pdf_binaries =
      consume_uploaded_entries(socket, :pdf, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case pdf_binaries do
      [{:ok, pdf}] ->
        pid = self()

        Task.start(fn ->
          case CatalogImporter.extract(pdf) do
            {:ok, items} -> send(pid, {:extracted, items})
            {:error, reason} -> send(pid, {:extract_failed, reason})
          end
        end)

        {:noreply, assign(socket, extracting: true, error: nil, preview: nil)}

      _ ->
        {:noreply, assign(socket, error: "No file received.")}
    end
  end

  @impl true
  def handle_event("load_json", %{"path" => path}, socket) do
    allowed = json_files_in_catalog()

    if path in allowed do
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, items} when is_list(items) ->
              {:noreply, socket |> assign(:preview, items) |> assign(:error, nil)}

            _ ->
              {:noreply, assign(socket, :error, "#{Path.basename(path)} is not a valid JSON array")}
          end

        {:error, reason} ->
          {:noreply, assign(socket, :error, "Could not read file: #{:file.format_error(reason)}")}
      end
    else
      {:noreply, assign(socket, :error, "File not allowed")}
    end
  end

  @impl true
  def handle_event("commit", _params, socket) do
    member = socket.assigns.current_member
    opts = [actor: member, tenant: member.organisation_id]

    {:ok, result} = CatalogImporter.commit(socket.assigns.preview, socket.assigns.catalog_id, opts)

    {:noreply, socket |> assign(:result, result) |> assign(:preview, nil)}
  end

  @impl true
  def handle_info({:extracted, items}, socket) do
    {:noreply, socket |> assign(:extracting, false) |> assign(:preview, items)}
  end

  @impl true
  def handle_info({:extract_failed, reason}, socket) do
    {:noreply, socket |> assign(:extracting, false) |> assign(:error, reason)}
  end

  defp json_files_in_catalog do
    dir = Path.join([File.cwd!(), "catalog"])

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort()
        |> Enum.map(&Path.join(dir, &1))

      {:error, _} ->
        []
    end
  end

  defp category_style("plant"), do: "background:rgba(219,146,88,0.15);color:#DB9258;"
  defp category_style("amendment"), do: "background:rgba(84,181,126,0.15);color:#54B57E;"
  defp category_style("container"), do: "background:rgba(90,180,216,0.15);color:#5AB4D8;"
  defp category_style(_), do: "background:rgba(110,103,90,0.2);color:#9A9384;"

  defp upload_error_label(:too_large), do: "File too large (max 20 MB)"
  defp upload_error_label(:not_accepted), do: "Only PDF files are accepted"
  defp upload_error_label(_), do: "Upload error"
end
