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

  end
end
