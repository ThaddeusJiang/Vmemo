defmodule Vmemo.AshRepo.Migrations.CreatePhotoCaptionRequests do
  use Ecto.Migration

  def up do
    create table(:photo_caption_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("uuid_generate_v7()")
      add :photo_id, references(:photos, type: :uuid, on_delete: :delete_all), null: false
      add :ash_user_id, references(:ash_users, type: :uuid, on_delete: :delete_all), null: false
      add :status, :text, null: false, default: "pending"
      add :caption, :text
      add :error_message, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:photo_caption_requests, [:photo_id])
    create index(:photo_caption_requests, [:ash_user_id])
    create index(:photo_caption_requests, [:status])
    create index(:photo_caption_requests, [:inserted_at])
  end

  def down do
    drop table(:photo_caption_requests)
  end
end
