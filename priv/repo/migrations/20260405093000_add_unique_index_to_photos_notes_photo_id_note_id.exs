defmodule Vmemo.Repo.Migrations.AddUniqueIndexToPhotosNotesPhotoIdNoteId do
  use Ecto.Migration

  def change do
    create unique_index(:photos_notes, [:photo_id, :note_id])
  end
end
