defmodule OpenSauce.Accounts.Checks.ApiScopeCheck do
  @moduledoc """
  Policy check that verifies API key scopes when a request is made via an API key.

  When no API key context is present (normal web user), the check passes.
  When an API key context is present, verifies the key has the required scope
  for the resource and action type.
  """
  use Ash.Policy.SimpleCheck

  @resource_scope_map %{
    OpenSauce.Catalog.Product => "products",
    OpenSauce.Catalog.BOM => "boms",
    OpenSauce.Catalog.BOMComponent => "bom_components",
    OpenSauce.Orders.Order => "orders",
    OpenSauce.Orders.OrderItem => "order_items",
    OpenSauce.Orders.ProductionBatch => "production_batches",
    OpenSauce.Inventory.Material => "materials",
    OpenSauce.Inventory.Lot => "lots",
    OpenSauce.Inventory.Movement => "movements",
    OpenSauce.Inventory.Supplier => "suppliers",
    OpenSauce.Inventory.PurchaseOrder => "purchase_orders",
    OpenSauce.CRM.Customer => "customers",
    OpenSauce.Settings.Settings => "settings"
  }

  @impl true
  def describe(_opts) do
    "API key has required scope for this resource and action"
  end

  @impl true
  def match?(_actor, %{resource: resource, action: action} = _context, _opts) do
    api_scopes = Process.get(:api_key_scopes)

    case api_scopes do
      nil ->
        # No API key context — normal web user, pass through
        true

      scopes when is_map(scopes) ->
        resource_key = Map.get(@resource_scope_map, resource)
        required_permission = action_type_to_permission(action.type)

        case Map.get(scopes, resource_key) do
          nil -> false
          permissions when is_list(permissions) -> required_permission in permissions
          _ -> false
        end
    end
  end

  defp action_type_to_permission(:read), do: "read"
  defp action_type_to_permission(:create), do: "write"
  defp action_type_to_permission(:update), do: "write"
  defp action_type_to_permission(:destroy), do: "write"
  defp action_type_to_permission(_), do: "read"
end
