defmodule OpenSauce.Orders do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  alias OpenSauce.Orders.Order

  json_api do
    prefix "/api/json"
  end

  graphql do
  end

  resources do
    resource Order do
      define :get_order_by_id, action: :read, get_by: [:id]
      define :get_order_by_reference, action: :read, get_by: [:reference]
      define :list_orders, action: :list
      define :list_orders_with_keyset, action: :keyset
      define :destroy_order, action: :destroy
    end

    resource OpenSauce.Orders.OrderItem do
      define :get_order_item_by_id, action: :read, get_by: [:id]
      define :update_item, action: :update
      define :list_order_items_for_plan, action: :plan_pending
    end

    resource OpenSauce.Orders.ProductionBatch do
      define :get_production_batch_by_id, action: :read, get_by: [:id]
      define :get_production_batch_by_code, action: :by_code
      define :list_production_batches, action: :read
      define :list_production_batches_filtered, action: :list
      define :list_production_batches_for_plan, action: :plan
      define :open_batch_with_allocations, action: :open_with_allocations
      define :start_batch, action: :start
      define :complete_batch, action: :complete
      define :list_open_batches_for_product, action: :open_for_product
    end

    resource OpenSauce.Orders.OrderItemLot do
      define :list_order_item_lots, action: :read
    end

    resource OpenSauce.Orders.OrderItemBatchAllocation do
      define :list_order_item_batch_allocations, action: :read
      define :create_order_item_batch_allocation, action: :create
      define :update_order_item_batch_allocation, action: :update
      define :destroy_order_item_batch_allocation, action: :destroy
      define :list_allocations_for_batch, action: :for_batch
    end

    resource OpenSauce.Orders.Job do
      define :list_jobs, action: :list
      define :list_upcoming_jobs, action: :upcoming
      define :get_job_by_id, action: :read, get_by: [:id]
      define :create_job, action: :create
      define :update_job, action: :update
      define :mark_job_in_progress, action: :mark_in_progress
      define :complete_job, action: :complete
      define :cancel_job, action: :cancel
      define :destroy_job, action: :destroy
    end

    resource OpenSauce.Orders.JobEvent do
      define :log_job_event, action: :log
      define :list_job_events, action: :for_job, args: [:job_id]
    end

    resource OpenSauce.Orders.JobPlant do
      define :create_job_plant, action: :create
      define :update_job_plant, action: :update
      define :destroy_job_plant, action: :destroy
    end

    resource OpenSauce.Orders.JobEventPlant do
      define :list_job_event_plants, action: :for_event, args: [:job_event_id]
      define :log_job_event_plant, action: :log
      define :destroy_job_event_plant, action: :destroy
    end

    resource OpenSauce.Orders.JobEventMaterial do
      define :list_job_event_materials, action: :for_event, args: [:job_event_id]
      define :log_job_event_material, action: :log
      define :destroy_job_event_material, action: :destroy
    end

    resource OpenSauce.Orders.JobMaterial do
      define :list_job_materials, action: :read
      define :create_job_material, action: :create
      define :update_job_material, action: :update
      define :destroy_job_material, action: :destroy
    end

    resource OpenSauce.Orders.ProductionBatchLot do
      define :create_production_batch_lot, action: :create
      define :list_production_batch_lots, action: :read
      define :destroy_production_batch_lot, action: :destroy
    end
  end
end
