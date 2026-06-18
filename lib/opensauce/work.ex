defmodule OpenSauce.Work do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    prefix "/api/json"
  end

  graphql do
  end

  resources do
    resource OpenSauce.Work.Job do
      define :find_active_shift, action: :active_shift
      define :list_jobs, action: :list
      define :list_upcoming_jobs, action: :upcoming
      define :list_jobs_for_shift, action: :for_shift, args: [:shift_id]
      define :list_jobs_at_garden, action: :at_garden, args: [:garden_id]
      define :get_job_by_id, action: :read, get_by: [:id]
      define :create_job, action: :create
      define :update_job, action: :update
      define :assign_job_invoice, action: :assign_invoice
      define :mark_job_in_progress, action: :mark_in_progress
      define :complete_job, action: :complete
      define :cancel_job, action: :cancel
      define :destroy_job, action: :destroy
    end

    resource OpenSauce.Work.JobEvent do
      define :log_job_event, action: :log
      define :list_job_events, action: :for_job, args: [:job_id]
    end

    resource OpenSauce.Work.JobEventMaterial do
      define :list_job_event_materials, action: :for_event, args: [:job_event_id]
      define :log_job_event_material, action: :log
      define :destroy_job_event_material, action: :destroy
    end

    resource OpenSauce.Work.JobStaff do
      define :assign_job_staff, action: :assign
      define :list_job_staff, action: :read
      define :unassign_job_staff, action: :destroy
    end

    resource OpenSauce.Work.JobEventStaff do
      define :log_job_event_staff, action: :log
      define :list_job_event_staff, action: :read
      define :destroy_job_event_staff, action: :destroy
    end

    resource OpenSauce.Work.JobMaterial do
      define :list_job_materials, action: :read
      define :create_job_material, action: :create
      define :update_job_material, action: :update
      define :move_job_material, action: :move
      define :destroy_job_material, action: :destroy
    end
  end
end
