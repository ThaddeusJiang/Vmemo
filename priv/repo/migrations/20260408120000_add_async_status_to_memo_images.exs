defmodule Vmemo.Repo.Migrations.AddAsyncStatusToMemoImages do
  use Ecto.Migration

  def up do
    alter table(:memo_images) do
      add :typesense_status, :text, null: false, default: "completed"
      add :moondream_status, :text, null: false, default: "completed"
    end
  end

  def down do
    alter table(:memo_images) do
      remove :moondream_status
      remove :typesense_status
    end
  end
end
