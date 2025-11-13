defmodule Vmemo.AshRepo.Migrations.RenameUserIdToAshUserId do
  use Ecto.Migration

  def up do
    # Rename photos.user_id to photos.ash_user_id
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'photos_user_id_fkey' AND table_name = 'photos'
      ) THEN
        ALTER TABLE photos DROP CONSTRAINT photos_user_id_fkey;
      END IF;
    END $$;
    """)

    # Convert user_id from uuid to text if needed, then rename
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'photos' AND column_name = 'user_id' AND data_type = 'uuid'
      ) THEN
        ALTER TABLE photos ALTER COLUMN user_id TYPE text USING user_id::text;
      END IF;
    END $$;
    """)

    rename table(:photos), :user_id, to: :ash_user_id

    execute("""
    ALTER TABLE photos
    ADD CONSTRAINT photos_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    # Rename notes.user_id to notes.ash_user_id
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'notes_user_id_fkey' AND table_name = 'notes'
      ) THEN
        ALTER TABLE notes DROP CONSTRAINT notes_user_id_fkey;
      END IF;
    END $$;
    """)

    # Convert user_id from uuid to text if needed, then rename
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notes' AND column_name = 'user_id' AND data_type = 'uuid'
      ) THEN
        ALTER TABLE notes ALTER COLUMN user_id TYPE text USING user_id::text;
      END IF;
    END $$;
    """)

    rename table(:notes), :user_id, to: :ash_user_id

    execute("""
    ALTER TABLE notes
    ADD CONSTRAINT notes_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)
  end

  def down do
    # Revert notes.ash_user_id to notes.user_id
    drop constraint(:notes, "notes_ash_user_id_fkey")
    rename table(:notes), :ash_user_id, to: :user_id
    execute("""
    ALTER TABLE notes
    ADD CONSTRAINT notes_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    # Revert photos.ash_user_id to photos.user_id
    drop constraint(:photos, "photos_ash_user_id_fkey")
    rename table(:photos), :ash_user_id, to: :user_id
    execute("""
    ALTER TABLE photos
    ADD CONSTRAINT photos_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)
  end
end
