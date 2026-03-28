defmodule Vmemo.AshRepo.Migrations.AddCaptionToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :caption, :text
    end
  end
end
