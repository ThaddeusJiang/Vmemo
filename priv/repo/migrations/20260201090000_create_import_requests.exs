defmodule Vmemo.AshRepo.Migrations.CreateImportRequests do
  use Ecto.Migration

  def up do
    create table(:import_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("uuid_generate_v7()")
      add :status, :text, null: false, default: "pending"
      add :source_filename, :text
      add :metadata, :jsonb
      add :result, :jsonb
      add :error_message, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:import_requests, [:status])
    create index(:import_requests, [:inserted_at])
  end

  def down do
    drop table(:import_requests)
  end
end
