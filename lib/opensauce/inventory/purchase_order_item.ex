defmodule OpenSauce.Inventory.PurchaseOrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_purchase_order_items"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [inserted_at: :asc], load: [:material, :purchase_order])
    end

    read :open_for_material do
      argument :material_id, :uuid do
        allow_nil? false
      end

      prepare build(
                sort: [inserted_at: :asc],
                load: [
                  :material,
                  purchase_order: [:supplier]
                ],
                filter: expr(material_id == ^arg(:material_id) and purchase_order.status != :received)
              )
    end

    create :create do
      primary? true

      accept [
        :purchase_order_id,
        :supplier_catalogue_item_id,
        :material_id,
        :supplier_sku,
        :quantity,
        :unit_price,
        :is_reservation
      ]
    end

    update :update do
      accept [:quantity, :unit_price, :is_reservation, :material_id]
    end

    # Called when supplier confirms availability and sets items aside.
    # confirmed_qty may be less than quantity if they are short.
    update :confirm do
      accept [:confirmed_qty, :unit_price]
    end

    # Called at pickup/receipt. received_qty reflects cherry-pick outcome —
    # she may take fewer than confirmed (passed on a specimen) or a damaged
    # one at a negotiated price.
    update :receive do
      accept [:received_qty, :unit_price]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    # Supplier's SKU, copied from catalogue item at PO build time so it is
    # stable even if the catalogue entry changes later.
    attribute :supplier_sku, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    # Requested quantity on the PO as sent to the supplier.
    attribute :quantity, :decimal do
      allow_nil? false
      default 1
      constraints min: 0
    end

    # Quantity supplier confirmed they have and set aside.
    # Nil until supplier responds. May be less than quantity.
    attribute :confirmed_qty, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    # Quantity actually taken at pickup after cherry-picking.
    # Nil until received. May be less than confirmed_qty.
    attribute :received_qty, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :unit_price, :decimal do
      allow_nil? true
      public? true
      constraints min: 0
    end

    # True for show plants she intends to inspect and cherry-pick individually.
    # Commodity items (false) are taken as-is in the requested quantity.
    attribute :is_reservation, :boolean do
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :purchase_order, OpenSauce.Inventory.PurchaseOrder do
      allow_nil? false
    end

    belongs_to :supplier_catalogue_item, OpenSauce.Inventory.SupplierCatalogueItem do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    # Nullable: may not exist in Material catalog yet when PO is built.
    # Gets linked when she receives and logs the stock.
    belongs_to :material, OpenSauce.Inventory.Material do
      allow_nil? true
      attribute_writable? true
    end
  end
end
