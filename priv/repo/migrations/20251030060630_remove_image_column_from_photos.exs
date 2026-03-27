defmodule Vmemo.AshRepo.Migrations.RemoveImageColumnFromPhotos do
  @moduledoc """
  Remove the `image` column from photos table.

  The image column was previously used to store base64-encoded image data,
  but caused UTF-8 encoding errors in PostgreSQL. Now images are stored
  as files and only the file path is kept in the `url` column.
  """
  use Ecto.Migration

  def up do
    alter table(:photos) do
      remove :image
    end
  end

  def down do
    alter table(:photos) do
      add :image, :text
    end
  end
end
