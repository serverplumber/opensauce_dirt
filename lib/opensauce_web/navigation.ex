defmodule OpenSauceWeb.Navigation do
  @moduledoc """
  Central registry for sidebar sub-navigation links and breadcrumb trails.

  LiveViews call `assign/3` (or `assign/4`) from `handle_params/3` with the
  current section and a declarative breadcrumb trail so that the layout can
  render consistent navigation affordances.
  """
  use OpenSauceWeb, :html

  alias OpenSauceWeb.PurchasingLive.Index
  alias OpenSauceWeb.PurchasingLive.Show
  alias OpenSauceWeb.PurchasingLive.Suppliers
  alias Phoenix.Component
  alias Phoenix.LiveView.Socket

  @type section ::
          :invoices
          | :inventory
          | :purchasing
          | :customers
          | :engagements
          | :venues
          | :settings

  # Inventory nav helpers
  @inventory_material_actions [
    :index,
    :new,
    :edit,
    :show,
    :details,
    :allergens,
    :nutritional_facts,
    :stock,
    :adjust
  ]

  def inventory_material_active?(socket), do: live_action(socket) in @inventory_material_actions

  # Purchasing nav helpers
  def purchasing_orders_active?(socket), do: socket.view in [Index, Show]
  def purchasing_suppliers_active?(socket), do: socket.view == Suppliers

  # Jobs nav helpers
  def jobs_active?(socket), do: String.starts_with?(Map.get(socket.assigns, :current_path, ""), "/manage/jobs")

  # Customers nav helpers
  def customers_list_active?(socket), do: String.starts_with?(Map.get(socket.assigns, :current_path, ""), "/manage/customers")
  def engagements_list_active?(socket), do: String.starts_with?(Map.get(socket.assigns, :current_path, ""), "/manage/engagements")

  # Venues nav helpers
  def venues_active?(socket), do: String.starts_with?(Map.get(socket.assigns, :current_path, ""), "/manage/venues")

  # Settings nav helpers
  defp settings_active?(:general, socket), do: live_action(socket) in [:index, :general]
  defp settings_active?(slug, socket), do: live_action(socket) == slug
  def settings_general_active?(socket), do: settings_active?(:general, socket)
  def settings_csv_active?(socket), do: settings_active?(:csv, socket)
  def settings_api_keys_active?(socket), do: settings_active?(:api_keys, socket)
  def settings_calendar_feed_active?(socket), do: settings_active?(:calendar_feed, socket)
  def settings_members_active?(socket), do: settings_active?(:members, socket)

  defp live_action(socket), do: Map.get(socket.assigns, :live_action)

  # Breadcrumb builders
  def crumb_invoice(%{reference: reference, id: id}) do
    %{label: reference, path: ~p"/manage/invoices/#{id}"}
  end

  def crumb_material(%{name: name, sku: sku}) do
    %{label: name, path: ~p"/manage/inventory/#{sku}"}
  end


  def crumb_material_stock(material) do
    %{label: "Stock", path: ~p"/manage/inventory/#{material.sku}/stock"}
  end

  def crumb_purchase_order(%{reference: reference}) do
    %{label: reference, path: ~p"/manage/purchasing/#{reference}"}
  end

  def crumb_purchase_order_items(%{reference: reference}) do
    %{label: "Items", path: ~p"/manage/purchasing/#{reference}/items"}
  end

  def crumb_purchase_order_add_item(%{reference: reference}) do
    %{label: "Add Item", path: ~p"/manage/purchasing/#{reference}/add_item"}
  end

  def crumb_supplier(%{name: name, id: id}) do
    %{label: name, path: ~p"/manage/purchasing/suppliers/#{id}/edit"}
  end

  def crumb_customer(%{full_name: full_name, reference: reference}) do
    %{label: full_name, path: ~p"/manage/customers/#{reference}"}
  end

  def crumb_customer_statistics(customer) do
    %{label: "Statistics", path: ~p"/manage/customers/#{customer.reference}/statistics"}
  end

  def crumb_customer_engagements(customer) do
    %{label: "Engagements", path: ~p"/manage/customers/#{customer.reference}/engagements"}
  end

  defp sections do
    %{
      invoices: %{
        label: "Invoices",
        path: "/manage/invoices",
        pages: %{
          new_invoice: %{label: "New Invoice", path: "/manage/invoices/new"},
          invoice: &__MODULE__.crumb_invoice/1
        },
        sub_links: []
      },
      inventory: %{
        label: "Inventory",
        path: "/manage/inventory",
        pages: %{
          new_material: %{label: "New Material", path: "/manage/inventory/new"},
          material: &__MODULE__.crumb_material/1,
          material_stock: &__MODULE__.crumb_material_stock/1
        },
        sub_links: []
      },
      purchasing: %{
        label: "Purchasing",
        path: "/manage/purchasing",
        pages: %{
          purchase_orders: %{label: "Purchase Orders", path: "/manage/purchasing"},
          new_purchase_order: %{label: "New Purchase Order", path: "/manage/purchasing/new"},
          purchase_order: &__MODULE__.crumb_purchase_order/1,
          po_items: &__MODULE__.crumb_purchase_order_items/1,
          po_add_item: &__MODULE__.crumb_purchase_order_add_item/1,
          suppliers: %{label: "Suppliers", path: "/manage/purchasing/suppliers"},
          new_supplier: %{label: "New Supplier", path: "/manage/purchasing/suppliers/new"},
          supplier: &__MODULE__.crumb_supplier/1
        },
        sub_links: [
          %{
            key: :purchase_orders,
            label: "Purchase Orders",
            navigate: "/manage/purchasing",
            active?: &__MODULE__.purchasing_orders_active?/1
          },
          %{
            key: :suppliers,
            label: "Suppliers",
            navigate: "/manage/purchasing/suppliers",
            active?: &__MODULE__.purchasing_suppliers_active?/1
          }
        ]
      },
      jobs: %{
        label: "Jobs",
        path: "/manage/jobs",
        pages: %{
          new_job: %{label: "New Job", path: "/manage/jobs/new"}
        },
        sub_links: []
      },
      customers: %{
        label: "Customers",
        path: "/manage/customers",
        pages: %{
          new_customer: %{label: "New Customer", path: "/manage/customers/new"},
          customer: &__MODULE__.crumb_customer/1,
          customer_statistics: &__MODULE__.crumb_customer_statistics/1,
          customer_engagements: &__MODULE__.crumb_customer_engagements/1
        },
        sub_links: [
          %{
            key: :customers,
            label: "Customers",
            navigate: "/manage/customers",
            active?: &__MODULE__.customers_list_active?/1
          },
          %{
            key: :engagements,
            label: "Engagements",
            navigate: "/manage/engagements",
            active?: &__MODULE__.engagements_list_active?/1
          }
        ]
      },
      engagements: %{
        label: "Engagements",
        path: "/manage/engagements",
        pages: %{},
        sub_links: [
          %{
            key: :customers,
            label: "Customers",
            navigate: "/manage/customers",
            active?: &__MODULE__.customers_list_active?/1
          },
          %{
            key: :engagements,
            label: "Engagements",
            navigate: "/manage/engagements",
            active?: &__MODULE__.engagements_list_active?/1
          }
        ]
      },
      venues: %{
        label: "Venues",
        path: "/manage/venues",
        pages: %{
          new_venue: %{label: "New Venue", path: "/manage/venues/new"}
        },
        sub_links: []
      },
      settings: %{
        label: "Organisation",
        path: "/manage/settings",
        pages: %{
          general: %{label: "Settings", path: "/manage/settings/general"},
          csv: %{label: "Import & Export", path: "/manage/settings/csv"},
          api_keys: %{label: "API Keys", path: "/manage/settings/api_keys"},
          calendar_feed: %{label: "Calendar Feed", path: "/manage/settings/calendar"},
          members: %{label: "Staff", path: "/manage/settings/members"}
        },
        sub_links: [
          %{
            key: :general,
            label: "Settings",
            navigate: "/manage/settings/general",
            active?: &__MODULE__.settings_general_active?/1
          },
          %{
            key: :api_keys,
            label: "API Keys",
            navigate: "/manage/settings/api_keys",
            active?: &__MODULE__.settings_api_keys_active?/1
          },
          %{
            key: :csv,
            label: "Import & Export",
            navigate: "/manage/settings/csv",
            active?: &__MODULE__.settings_csv_active?/1
          },
          %{
            key: :calendar_feed,
            label: "Calendar Feed",
            navigate: "/manage/settings/calendar",
            active?: &__MODULE__.settings_calendar_feed_active?/1
          },
          %{
            key: :members,
            label: "Staff",
            navigate: "/manage/settings/members",
            active?: &__MODULE__.settings_members_active?/1
          }
        ]
      },
    }
  end

  @resource_sections %{
    material: :inventory,
    purchase_order: :purchasing,
    supplier: :purchasing,
    customer: :customers,
    invoice: :invoices
  }

  @doc """
  Assigns both breadcrumb and nav sub-link data to the socket.

  ## Examples

      socket
      |> Navigation.assign(:orders, [
        Navigation.root(:orders),
        Navigation.resource(:order, order)
      ])
  """
  @spec assign(Socket.t(), section(), list(), keyword()) ::
          Socket.t()
  def assign(socket, section, trail, _opts \\ []) do
    normalized_trail =
      trail
      |> List.wrap()
      |> Enum.map(&normalize_token/1)

    breadcrumbs = build_breadcrumbs(section, normalized_trail)
    nav_sub_links = nav_links_for(section, socket)

    socket
    |> Component.assign(:nav_sub_links, nav_sub_links)
    |> Component.assign(:breadcrumbs, breadcrumbs)
  end

  @doc """
  Helper to reference the root crumb for a section.
  """
  def root(section) when is_atom(section), do: {section, :root}

  @doc """
  Helper to reference a section-specific page crumb.
  """
  def page(section, slug, data \\ nil) when is_atom(section) and is_atom(slug), do: {section, slug, data}

  @doc """
  Helper to reference resource-backed breadcrumb entries (orders, suppliers, etc).
  """
  def resource(type, data) when is_atom(type), do: {type, data}

  defp nav_links_for(section, socket) do
    case Map.get(sections(), section) do
      %{sub_links: links} when is_list(links) ->
        links
        |> Enum.filter(&link_visible?(&1, socket))
        |> Enum.map(&materialize_link(&1, socket))

      _ ->
        []
    end
  end

  defp link_visible?(%{show?: fun}, socket) when is_function(fun, 1), do: fun.(socket)
  defp link_visible?(_, _), do: true

  defp materialize_link(link, socket) do
    link
    |> Map.take([:label, :navigate, :description, :icon])
    |> Map.put(:active, nav_active?(link, socket))
  end

  defp nav_active?(%{active?: fun}, socket) when is_function(fun, 1), do: fun.(socket)
  defp nav_active?(_, _), do: false

  defp build_breadcrumbs(section, tokens) do
    tokens =
      case tokens do
        [] -> [normalize_token(root(section))]
        _ -> tokens
      end

    crumbs =
      tokens
      |> Enum.map(&materialize_crumb/1)
      |> Enum.reject(&is_nil/1)

    total = Enum.count(crumbs)

    crumbs
    |> Enum.with_index()
    |> Enum.map(fn {crumb, idx} ->
      Map.put(crumb, :current?, idx == total - 1)
    end)
  end

  defp materialize_crumb({:custom, %{label: _} = crumb}) do
    Map.put_new(crumb, :path, Map.get(crumb, :path))
  end

  defp materialize_crumb({:section, section, slug, data}) do
    section_config = Map.fetch!(sections(), section)

    entry =
      case slug do
        :root ->
          %{label: section_config.label, path: section_config.path}

        _ ->
          section_config
          |> Map.get(:pages, %{})
          |> Map.fetch!(slug)
      end

    normalize_entry(entry, data, section, slug)
  end

  defp materialize_crumb(_), do: nil

  defp normalize_entry(entry, data, section, slug) when is_function(entry, 1),
    do: entry.(data) || raise_breadcrumb_error(section, slug)

  defp normalize_entry(%{label: _} = entry, _data, _section, _slug) do
    Map.put_new(entry, :path, Map.get(entry, :path))
  end

  defp normalize_entry(_, _, section, slug), do: raise_breadcrumb_error(section, slug)

  defp raise_breadcrumb_error(section, slug) do
    raise ArgumentError,
          "missing breadcrumb builder for #{inspect({section, slug})} – ensure the trail includes required data"
  end

  defp normalize_token(%{label: _} = crumb), do: {:custom, crumb}

  defp normalize_token({section, slug}) when is_atom(section) and is_atom(slug), do: {:section, section, slug, nil}

  defp normalize_token({section, slug, data}) when is_atom(section) and is_atom(slug), do: {:section, section, slug, data}

  defp normalize_token({resource, data}) when is_atom(resource) do
    case Map.fetch(@resource_sections, resource) do
      {:ok, section} ->
        {:section, section, resource, data}

      :error when is_map(data) ->
        {:custom, data}

      :error ->
        raise ArgumentError, "unknown breadcrumb token #{inspect({resource, data})}"
    end
  end
end
