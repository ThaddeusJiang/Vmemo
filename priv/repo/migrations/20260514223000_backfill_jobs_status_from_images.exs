defmodule Vmemo.Repo.Migrations.BackfillJobsStatusFromImages do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE jobs AS j
    SET status = 'completed', updated_at = timezone('utc', now())
    FROM memo_images AS i
    WHERE j.image_id = i.id
      AND j.kind = 'caption'
      AND j.status IN ('requested', 'queue', 'in_progress')
      AND i.moondream_status = 'completed'
      AND NULLIF(BTRIM(COALESCE(i.caption, '')), '') IS NOT NULL;
    """)

    execute("""
    UPDATE jobs AS j
    SET status = 'completed', updated_at = timezone('utc', now())
    FROM memo_images AS i
    WHERE j.image_id = i.id
      AND j.kind = 'typesense'
      AND j.status IN ('requested', 'queue', 'in_progress')
      AND i.typesense_status = 'completed';
    """)

    execute("""
    UPDATE jobs AS j
    SET status = 'failed', updated_at = timezone('utc', now())
    FROM memo_images AS i
    WHERE j.image_id = i.id
      AND j.kind = 'caption'
      AND j.status IN ('requested', 'queue', 'in_progress')
      AND i.moondream_status = 'failed';
    """)

    execute("""
    UPDATE jobs AS j
    SET status = 'failed', updated_at = timezone('utc', now())
    FROM memo_images AS i
    WHERE j.image_id = i.id
      AND j.kind = 'typesense'
      AND j.status IN ('requested', 'queue', 'in_progress')
      AND i.typesense_status = 'failed';
    """)
  end

  def down do
    :ok
  end
end
