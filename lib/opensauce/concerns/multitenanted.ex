defmodule OpenSauce.Concerns.Multitenanted do
  use Spark.Dsl.Fragment,
    of: Ash.Resource

  multitenancy do
    strategy :attribute
    attribute :organisation_id
  end

  attributes do
    attribute :organisation_id, :uuid, allow_nil?: false, public?: false
  end

  relationships do
    belongs_to :organisation, OpenSauce.Accounts.Organisation,
      domain: OpenSauce.Accounts,
      allow_nil?: false
  end
end
