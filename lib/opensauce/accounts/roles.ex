defmodule OpenSauce.Accounts.Roles do
  @moduledoc false

  # Role hierarchy: owner > manager > staff

  def owner?(%{role: :owner}), do: true
  def owner?(_), do: false

  def manager_or_above?(%{role: role}) when role in [:owner, :manager], do: true
  def manager_or_above?(_), do: false

  # Any active member can read; these gates are for write/admin operations.
  def can_manage_members?(actor), do: manager_or_above?(actor)
  def can_create_staff?(actor), do: manager_or_above?(actor)
  def can_create_managers?(actor), do: owner?(actor)
  def can_promote_to_owner?(actor), do: owner?(actor)
  def can_remove_member?(actor), do: manager_or_above?(actor)
end
