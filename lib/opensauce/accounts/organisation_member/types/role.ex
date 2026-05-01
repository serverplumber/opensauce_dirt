defmodule OpenSauce.Accounts.OrganisationMember.Types.Role do
  @moduledoc false
  use Ash.Type.Enum, values: [:owner, :manager, :staff]
end
