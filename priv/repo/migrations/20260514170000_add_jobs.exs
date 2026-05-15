defmodule Vmemo.Repo.Migrations.AddJobs do
  use Ecto.Migration

  def change do
    create table(:jobs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :image_id, :uuid, null: false
      add :user_id, :uuid, null: false
      add :kind, :text, null: false
      add :status, :text, null: false, default: "requested"
      add :worker, :text
      add :oban_job_id, :bigint
      add :error, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:jobs, [:image_id, :kind], name: :jobs_image_kind_index)
    create index(:jobs, [:user_id])
    create index(:jobs, [:status])
    create index(:jobs, [:inserted_at])
  end
end
