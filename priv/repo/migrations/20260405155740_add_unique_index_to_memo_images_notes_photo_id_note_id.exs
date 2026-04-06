defmodule Vmemo.Repo.Migrations.AddUniqueIndexToMemoImagesNotesPhotoIdNoteId do
  use Ecto.Migration

  def change do
    create unique_index(:memo_images_notes, [:photo_id, :note_id])
  end
end
