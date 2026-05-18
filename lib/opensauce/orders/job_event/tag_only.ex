defmodule OpenSauce.Orders.JobEvent.TagOnly do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      public? true
    end
  end
end
