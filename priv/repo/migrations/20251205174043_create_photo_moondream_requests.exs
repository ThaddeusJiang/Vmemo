defmodule Vmemo.AshRepo.Migrations.CreatePhotoMoondreamRequests do
  use Ecto.Migration

  def up do
    create table(:photo_moondream_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("uuid_generate_v7()")
      add :photo_id, references(:photos, type: :uuid, on_delete: :delete_all), null: false
      add :ash_user_id, references(:ash_users, type: :uuid, on_delete: :delete_all), null: false
      add :function_type, :text, null: false
      add :prompt, :text
      add :result, :jsonb
      add :status, :text, null: false, default: "pending"
      add :error_message, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:photo_moondream_requests, [:photo_id])
    create index(:photo_moondream_requests, [:ash_user_id])
    create index(:photo_moondream_requests, [:status])
    create index(:photo_moondream_requests, [:inserted_at])
  end

  def down do
    drop table(:photo_moondream_requests)
  end
end
