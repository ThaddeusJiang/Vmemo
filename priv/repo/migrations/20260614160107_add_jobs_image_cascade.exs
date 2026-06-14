defmodule Vmemo.Repo.Migrations.AddJobsImageCascade do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM jobs AS j
    WHERE NOT EXISTS (
      SELECT 1
      FROM memo_images AS i
      WHERE i.id = j.image_id
    )
    """)

    alter table(:jobs) do
      modify :image_id,
             references(:memo_images,
               column: :id,
               name: "jobs_image_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             ),
             null: false
    end
  end

  def down do
    drop constraint(:jobs, "jobs_image_id_fkey")
  end
end
