defmodule OpenSauce.Inventory do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    prefix "/api/json"
  end

  graphql do
  end

  resources do
    resource OpenSauce.Inventory.Lot do
      define :get_lot_by_id, action: :read, get_by: [:id]
      define :list_lots, action: :read
      define :list_available_lots_for_material, action: :available_for_material
    end

    resource OpenSauce.Inventory.Material do
      define :get_material_by_id, action: :read, get_by: [:id]
      define :get_material_by_sku, action: :read, get_by: [:sku]
      define :list_materials, action: :list
      define :list_materials_with_keyset, action: :keyset
      define :destroy_material, action: :destroy
    end

    resource OpenSauce.Inventory.Movement do
      define :adjust_stock, action: :adjust_stock
      define :list_movements, action: :read
    end

    resource OpenSauce.Inventory.Supplier do
      define :get_supplier_by_id, action: :read, get_by: [:id]
      define :list_suppliers, action: :list
      define :create_supplier, action: :create
      define :update_supplier, action: :update
    end

    resource OpenSauce.Inventory.SupplierCatalogue do
      define :list_supplier_catalogues, action: :list
      define :get_supplier_catalogue_by_id, action: :read, get_by: [:id]
      define :create_supplier_catalogue, action: :create
      define :update_supplier_catalogue, action: :update
      define :delete_supplier_catalogue, action: :destroy
    end

    resource OpenSauce.Inventory.SupplierCatalogueItem do
      define :list_supplier_catalogue_items, action: :list
      define :search_supplier_catalogue_items, action: :search, args: [:query]
      define :get_supplier_catalogue_item_by_id, action: :read, get_by: [:id]
      define :create_supplier_catalogue_item, action: :create
      define :update_supplier_catalogue_item, action: :update
      define :delete_supplier_catalogue_item, action: :destroy
    end

    resource OpenSauce.Inventory.PurchaseOrder do
      define :get_purchase_order_by_id, action: :read, get_by: [:id]
      define :get_purchase_order_by_reference, action: :read, get_by: [:reference]
      define :list_purchase_orders, action: :list
      define :create_purchase_order, action: :create
      define :update_purchase_order, action: :update
      define :mark_purchase_order_ordered, action: :mark_ordered
      define :confirm_purchase_order, action: :confirm
      define :receive_purchase_order, action: :receive
    end

    resource OpenSauce.Inventory.PurchaseOrderItem do
      define :get_purchase_order_item_by_id, action: :read, get_by: [:id]
      define :list_purchase_order_items, action: :list
      define :list_open_po_items_for_material, action: :open_for_material
      define :create_purchase_order_item, action: :create
      define :update_purchase_order_item, action: :update
      define :confirm_purchase_order_item, action: :confirm
      define :receive_purchase_order_item, action: :receive
    end

  end
end
