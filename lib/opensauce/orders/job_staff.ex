defmodule OpenSauce.Orders.JobStaff do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "orders_job_staff"
    repo OpenSauce.Repo

    custom_indexes do
      index [:job_id], name: "orders_job_staff_job_id_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :assign do
      primary? true
      accept [:job_id, :member_id, :organisation_id]
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
    timestamps()
  end

  relationships do
    belongs_to :job, OpenSauce.Orders.Job do
      allow_nil? false
      public? true
    end

    belongs_to :member, OpenSauce.Accounts.OrganisationMember do
      allow_nil? false
      public? true
      domain OpenSauce.Accounts
    end
  end

  identities do
    identity :unique_staff_assignment, [:job_id, :member_id]
  end
end
