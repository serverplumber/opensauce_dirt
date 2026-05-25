defmodule OpenSauce.Orders.Job.Validations.RequireGardenForAddressable do
  @moduledoc false
  use Ash.Resource.Validation

  @addressable_categories [:installation, :pruning, :consultation, :design, :opening, :winterization]

  @impl true
  def validate(changeset, _opts, _context) do
    type = Ash.Changeset.get_attribute(changeset, :type)
    category = Ash.Changeset.get_attribute(changeset, :service_category)
    garden_id = Ash.Changeset.get_attribute(changeset, :garden_id)

    if type == :client_work and category in @addressable_categories and is_nil(garden_id) do
      {:error, field: :garden_id, message: "is required for #{category} jobs"}
    else
      :ok
    end
  end
end
