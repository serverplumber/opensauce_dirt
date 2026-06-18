# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Work.JobEventStaff do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Work,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_event_staff"
    repo OpenSauce.Repo

    custom_indexes do
      index [:job_event_id], name: "orders_job_event_staff_job_event_id_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :log do
      primary? true
      accept [:job_event_id, :member_id, :man_hour_rate, :organisation_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    # Snapshotted from OrganisationMember.labor_hourly_rate at log time.
    attribute :man_hour_rate, :decimal do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    timestamps()
  end

  relationships do
    belongs_to :job_event, OpenSauce.Work.JobEvent do
      allow_nil? false
      public? true
    end

    belongs_to :member, OpenSauce.Accounts.OrganisationMember do
      allow_nil? false
      public? true
      domain OpenSauce.Accounts
    end
  end
end
