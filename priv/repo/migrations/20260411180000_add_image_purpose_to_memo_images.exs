defmodule Vmemo.Repo.Migrations.AddImagePurposeToMemoImages do
  use Ecto.Migration

  def up do
    alter table(:memo_images) do
      add :_purpose, :text
    end
  end

  def down do
    alter table(:memo_images) do
      remove :_purpose
    end
  end
end
