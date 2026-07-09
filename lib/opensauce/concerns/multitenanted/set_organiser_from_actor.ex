defmodule OpenSauce.Concerns.Multitenanted.SetOrganisationFromActor do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: %{organisation_id: org_id}}) do
    Ash.Changeset.force_change_attribute(changeset, :organisation_id, org_id)
  end

  def change(changeset, _opts, _context), do: changeset

  @impl true
  def atomic(_changeset, _opts, %{actor: %{organisation_id: org_id}}) do
    {:atomic_set, %{organisation_id: org_id}}
  end

  def atomic(_changeset, _opts, _context), do: :ok
end
