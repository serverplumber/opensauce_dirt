defmodule OpenSauce.Concerns.Venued do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    attribute :venue_id, :uuid, allow_nil?: false, public?: false
  end

  relationships do
    belongs_to :venue, OpenSauce.Operations.Venue,
      domain: OpenSauce.Operations,
      allow_nil?: false
  end
end
