defmodule Vmemo.Repo.Migrations.RenameMemoJobsToJobs do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF to_regclass('public.memo_jobs') IS NOT NULL AND to_regclass('public.jobs') IS NULL THEN
        ALTER TABLE public.memo_jobs RENAME TO jobs;
      END IF;

      IF to_regclass('public.memo_jobs_image_kind_index') IS NOT NULL THEN
        ALTER INDEX public.memo_jobs_image_kind_index RENAME TO jobs_image_kind_index;
      END IF;
    END
    $$;
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF to_regclass('public.jobs') IS NOT NULL AND to_regclass('public.memo_jobs') IS NULL THEN
        ALTER TABLE public.jobs RENAME TO memo_jobs;
      END IF;

      IF to_regclass('public.jobs_image_kind_index') IS NOT NULL THEN
        ALTER INDEX public.jobs_image_kind_index RENAME TO memo_jobs_image_kind_index;
      END IF;
    END
    $$;
    """)
  end
end
