defmodule Vmemo.AshRepo.Migrations.AddTsOcrToPhotos do
  use Ecto.Migration

  def up do
    alter table(:photos) do
      add :ts_ocr, :text
    end
  end

  def down do
    alter table(:photos) do
      remove :ts_ocr
    end
  end
end
