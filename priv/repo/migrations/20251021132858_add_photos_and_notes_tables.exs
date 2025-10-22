defmodule Vmemo.Repo.Migrations.AddPhotosAndNotesTables do
  use Ecto.Migration

  def change do
    create table(:photos, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :url, :text, null: false
      add :note, :text
      add :file_id, :text
      add :image, :text
      add :user_id, :text

      timestamps(type: :utc_datetime)
    end

    create table(:notes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :text, :text, null: false
      add :user_id, :text

      timestamps(type: :utc_datetime)
    end

    create table(:photos_notes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :photo_id, references(:photos, type: :uuid, on_delete: :delete_all), null: false
      add :note_id, references(:notes, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:photos_notes, [:photo_id])
    create index(:photos_notes, [:note_id])
    create unique_index(:photos_notes, [:photo_id, :note_id])
  end
end
