defmodule OpenSauce.Operations do
  @moduledoc false
  use Ash.Domain

  resources do
    resource OpenSauce.Operations.Venue do
      define :create_venue,            action: :create
      define :list_venues,             action: :read
      define :get_venue,               action: :read,   get_by: [:id]
      define :update_venue,            action: :update
    end

    resource OpenSauce.Operations.StorageLocation do
      define :create_storage_location, action: :create
      define :list_storage_locations,  action: :read
      define :update_storage_location, action: :update
      define :delete_storage_location, action: :destroy
    end

    resource OpenSauce.Operations.Shift do
      define :create_shift,            action: :create
      define :list_shifts,             action: :read
      define :update_shift,            action: :update
      define :delete_shift,            action: :destroy
    end
  end
end
