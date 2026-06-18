defmodule OpenSauce.Work.JobEvent.OdometerData do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:arrival, :departure, :shift_start, :shift_end]
    end

    attribute :odometer_km, :integer do
      allow_nil? true
      public? true
      constraints min: 0
    end
  end
end
