defmodule OpenSauce.Orders.OrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    fragments: [OpenSauce.Concerns.Multitenanted]

  json_api do
    type "order-item"

    routes do
      base("/order-items")
      get(:read)
      index :read
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :order_item

    queries do
      get(:get_order_item, :read)
      list(:list_order_items, :read)
    end

    mutations do
      create :create_order_item, :create
      update :update_order_item, :update
    end
  end

  postgres do
    table "orders_items"
    repo OpenSauce.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :quantity, :unit_price, :status]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:quantity, :status]
    end

    read :in_range do
      description "Order items whose order delivery_date falls within a datetime range."

      argument :start_date, :utc_datetime do
        allow_nil? false
      end

      argument :end_date, :utc_datetime do
        allow_nil? false
      end

      argument :product_ids, {:array, :uuid} do
        allow_nil? true
        default nil
      end

      argument :exclude_order_id, :uuid do
        allow_nil? true
        default nil
      end

      prepare build(load: [:product, :order])

      filter expr(order.delivery_date >= ^arg(:start_date) and order.delivery_date <= ^arg(:end_date))
      filter expr(is_nil(^arg(:product_ids)) or product_id in ^arg(:product_ids))
      filter expr(is_nil(^arg(:exclude_order_id)) or order_id != ^arg(:exclude_order_id))
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {OpenSauce.Accounts.Checks.ApiScopeCheck, []}
    end

    bypass action(:in_range) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :unit_price, :decimal do
      allow_nil? false
    end

    attribute :quantity, :decimal do
      allow_nil? false
    end

    attribute :status, :atom do
      allow_nil? false
      default :todo
      constraints one_of: [:todo, :in_progress, :done]
    end

    timestamps()
  end

  relationships do
    belongs_to :order, OpenSauce.Orders.Order do
      allow_nil? false
    end

    belongs_to :product, OpenSauce.Catalog.Product do
      allow_nil? false
    end

    belongs_to :bom, OpenSauce.Catalog.BOM do
      allow_nil? true
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * unit_price)
  end
end
