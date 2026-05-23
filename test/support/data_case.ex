defmodule OpenSauce.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use OpenSauce.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias OpenSauce.Accounts.{Organisation, OrganisationMember, User}
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import OpenSauce.DataCase
      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      alias OpenSauce.Repo
    end
  end

  setup tags do
    OpenSauce.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(OpenSauce.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Returns an OrganisationMember with role :staff for use as an actor in Ash domain calls.
  """
  def staff_actor, do: create_member!(:staff)

  @doc """
  Returns an OrganisationMember with role :owner for use as an actor in Ash domain calls.
  """
  def admin_actor, do: create_member!(:owner)

  defp create_member!(role) do
    email = "#{role}+#{System.unique_integer([:positive])}@local"

    user =
      User
      |> Ash.Changeset.for_create(:create, %{email: email})
      |> Ash.create!(authorize?: false)

    n = System.unique_integer([:positive])

    org =
      Organisation
      |> Ash.Changeset.for_create(:create, %{name: "Test Org #{n}", slug: "test-org-#{n}"})
      |> Ash.create!(authorize?: false)

    OrganisationMember
    |> Ash.Changeset.for_create(:create, %{role: role, user_id: user.id, organisation_id: org.id})
    |> Ash.create!(authorize?: false)
  end
end
