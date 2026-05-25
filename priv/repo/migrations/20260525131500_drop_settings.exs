defmodule OpenSauce.Repo.Migrations.DropSettings do
  use Ecto.Migration

  def up do
    drop table(:settings)
  end

  def down do
    create table(:settings, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :retail_markup_mode, :text, null: false, default: "percent"
      add :retail_markup_value, :decimal, null: false, default: "0"
      add :wholesale_markup_mode, :text, null: false, default: "percent"
      add :wholesale_markup_value, :decimal, null: false, default: "0"
      add :organisation_id, references(:accounts_organisations, type: :uuid), null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end
  end
end
