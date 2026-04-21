defmodule Vmemo.Repo.Migrations.AddTypesenseStatusToMemoNotes do
  use Ecto.Migration

  def up do
    alter table(:memo_notes) do
      add :typesense_status, :text, null: false, default: "completed"
    end
  end

  def down do
    alter table(:memo_notes) do
      remove :typesense_status
    end
  end
end
