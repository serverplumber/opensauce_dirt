defmodule OpenSauce.Operations do
  @moduledoc false
  use Ash.Domain

  resources do
    resource OpenSauce.Operations.Venue do
      define :create_venue,            action: :create
      define :list_venues,             action: :read
      define :get_venue,               action: :read,        get_by: [:id]
      define :update_venue,            action: :update
      define :delete_venue,            action: :destroy
    end

    resource OpenSauce.Operations.StorageLocation do
      define :create_storage_location,          action: :create
      define :list_storage_locations,           action: :read
      define :list_storage_locations_for_venue, action: :list_for_venue, args: [:venue_id]
      define :get_storage_location,             action: :read,           get_by: [:id]
      define :update_storage_location,          action: :update
      define :delete_storage_location,          action: :destroy
    end

  end
end
