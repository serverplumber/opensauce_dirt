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
     Navigation.assign(socket, :purchasing, [
       Navigation.root(:purchasing),
       Navigation.page(:purchasing, :suppliers),
       Navigation.resource(:supplier, socket.assigns.supplier),
       %{label: "Import Catalog", path: nil}
     ])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Import Catalog — {@supplier.name}
      <:subtitle>Upload a supplier PDF and Claude will extract the items for review.</:subtitle>
    </.header>

    <div class="mt-6 space-y-6 max-w-3xl">
      <div class="rounded-lg border border-stone-200 bg-white p-5">
        <h3 class="mb-3 text-sm font-semibold text-stone-700">Catalog</h3>

        <div class="space-y-2">
          <label
            :for={cat <- @catalogs}
            class={[
              "flex cursor-pointer items-center gap-3 rounded-md border px-3 py-2 text-sm transition",
              if(@catalog_id == cat.id,
                do: "border-primary-400 bg-primary-50",
                else: "border-stone-200 hover:border-stone-300"
              )
            ]}
          >
            <input
              type="radio"
              name="catalog_id"
              value={cat.id}
              checked={@catalog_id == cat.id}
              phx-click="select_catalog"
              phx-value-id={cat.id}
              class="accent-primary-600"
            />
            <span class="font-medium text-stone-700">{cat.name}</span>
            <span class="text-stone-400">{cat.year}</span>
          </label>
        </div>

        <details class="mt-3">
          <summary class="cursor-pointer text-xs text-primary-600 hover:text-primary-700">
            + New catalog
          </summary>
          <form phx-submit="create_catalog" class="mt-2 flex gap-2">
            <input
              type="text"
              placeholder="Name (e.g. Spring 2026)"
              name="name"
              required
              class="flex-1 rounded border border-stone-300 px-2 py-1 text-sm focus:border-primary-400 focus:outline-none"
            />
            <input
              type="number"
              name="year"
              value={Date.utc_today().year}
              class="w-24 rounded border border-stone-300 px-2 py-1 text-sm focus:border-primary-400 focus:outline-none"
            />
            <.button type="submit" variant={:outline} class="shrink-0">
              Create
            </.button>
          </form>
        </details>
      </div>

      <div class="rounded-lg border border-stone-200 bg-white p-5">
        <h3 class="mb-3 text-sm font-semibold text-stone-700">PDF</h3>

        <div
          class="flex flex-col items-center justify-center rounded-md border-2 border-dashed border-stone-300 px-6 py-10 text-center"
          phx-drop-target={@uploads.pdf.ref}
        >
          <.live_file_input upload={@uploads.pdf} />
          <p class="mt-1 text-xs text-stone-400">Max 20 MB · PDF only</p>

          <div :for={entry <- @uploads.pdf.entries} class="mt-3 w-full">
            <div class="flex items-center gap-2 rounded border border-stone-200 bg-stone-50 px-3 py-2 text-sm">
              <.icon name="hero-document" class="h-4 w-4 shrink-0 text-stone-400" />
              <span class="min-w-0 flex-1 truncate text-stone-700">{entry.client_name}</span>
              <span class="text-stone-400">{Float.round(entry.client_size / 1_000_000, 1)} MB</span>
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="text-stone-300 hover:text-red-400"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
            <div :for={err <- upload_errors(@uploads.pdf, entry)} class="mt-1 text-xs text-red-500">
              {upload_error_label(err)}
            </div>
          </div>
        </div>

        <div class="mt-4 flex justify-end">
          <.button
            type="button"
            phx-click="extract"
            variant={:primary}
            disabled={@uploads.pdf.entries == [] or is_nil(@catalog_id) or @extracting}
            phx-disable-with="Extracting…"
          >
            {if @extracting, do: "Extracting…", else: "Extract with Claude"}
          </.button>
        </div>

        <div :if={@error} class="mt-3 rounded-md bg-red-50 px-4 py-3 text-sm text-red-700">
          {@error}
        </div>
      </div>

      <div :if={@json_files != []} class="rounded-lg border border-stone-200 bg-white p-5">
        <h3 class="mb-3 text-sm font-semibold text-stone-700">Load from JSON</h3>
        <div class="space-y-2">
          <div :for={path <- @json_files} class="flex items-center justify-between gap-3">
            <span class="font-mono text-xs text-stone-500">{Path.basename(path)}</span>
            <.button
              type="button"
              phx-click="load_json"
              phx-value-path={path}
              variant={:outline}
              size={:sm}
              disabled={is_nil(@catalog_id)}
            >
              Load
            </.button>
          </div>
        </div>
        <p :if={is_nil(@catalog_id)} class="mt-2 text-xs text-stone-400">
          Select a catalog above first.
        </p>
      </div>

      <div :if={@preview} class="rounded-lg border border-stone-200 bg-white">
        <div class="flex items-center justify-between border-b border-stone-100 px-5 py-3">
          <h3 class="text-sm font-semibold text-stone-700">
            Preview — {length(@preview)} items extracted
          </h3>
          <.button
            type="button"
            phx-click="commit"
            variant={:primary}
            phx-disable-with="Importing…"
          >
            Import All
          </.button>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-stone-100 text-sm">
            <thead class="bg-stone-50">
              <tr>
                <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">SKU</th>
                <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">Name</th>
                <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">Latin Name</th>
                <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">Cultivar</th>
                <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">Format</th>
                <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-stone-500">Category</th>
                <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wide text-stone-500">Price</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-stone-50 bg-white">
              <tr :for={item <- @preview} class="hover:bg-stone-50">
                <td class="px-3 py-2 font-mono text-xs text-stone-600">{item["sku"]}</td>
                <td class="px-3 py-2 text-stone-700">{item["name"]}</td>
                <td class="px-3 py-2 italic text-stone-500">{item["latin_name"]}</td>
                <td class="px-3 py-2 text-stone-500">{item["cultivar"]}</td>
                <td class="px-3 py-2 text-stone-500">{item["format_description"]}</td>
                <td class="px-3 py-2">
                  <span class={["rounded px-1.5 py-0.5 text-xs font-medium", category_class(item["category"])]}>
                    {item["category"]}
                  </span>
                </td>
                <td class="px-3 py-2 text-right text-stone-600">
                  {if item["unit_price"], do: item["unit_price"], else: "—"}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div :if={@result} class="rounded-md bg-emerald-50 px-5 py-4 text-sm text-emerald-800">
        Imported {@result.created} items.
        <span :if={@result.failed > 0} class="text-amber-700">
          {@result.failed} failed — check logs.
        </span>
        <.link navigate={~p"/manage/purchasing/suppliers"} class="ml-3 underline">
          Back to suppliers
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_catalog", %{"id" => id}, socket) do
    {:noreply, assign(socket, :catalog_id, id)}
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
        catalogs = [cat | socket.assigns.catalogs]
        {:noreply, socket |> assign(:catalogs, catalogs) |> assign(:catalog_id, cat.id)}

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
    # consume_uploaded_entries must run in the LV process — read bytes here,
    # then hand them to a task for the blocking API call.
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

  defp category_class("plant"), do: "bg-emerald-50 text-emerald-700"
  defp category_class("amendment"), do: "bg-amber-50 text-amber-700"
  defp category_class("container"), do: "bg-blue-50 text-blue-700"
  defp category_class(_), do: "bg-stone-100 text-stone-600"

  defp upload_error_label(:too_large), do: "File too large (max 20 MB)"
  defp upload_error_label(:not_accepted), do: "Only PDF files are accepted"
  defp upload_error_label(_), do: "Upload error"
end
