defmodule OpenSauce.Repo.Migrations.EnablePgTrgm do
  use Ecto.Migration

  def up, do: execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
  def down, do: execute("DROP EXTENSION IF EXISTS pg_trgm")
end
