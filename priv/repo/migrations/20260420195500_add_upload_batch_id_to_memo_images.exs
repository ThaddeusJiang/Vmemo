defmodule Vmemo.Repo.Migrations.AddUploadBatchIdToMemoImages do
  use Ecto.Migration

  def change do
    alter table(:memo_images) do
      add :upload_batch_id, :uuid
    end

    create index(:memo_images, [:user_id, :upload_batch_id, :inserted_at])
  end
end
