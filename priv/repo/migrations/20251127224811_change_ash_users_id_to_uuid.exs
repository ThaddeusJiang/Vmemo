defmodule Vmemo.AshRepo.Migrations.ChangeAshUsersIdToUuid do
  use Ecto.Migration

  def up do
    # Step 1: Drop all foreign key constraints
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'ash_user_tokens_ash_user_id_fkey' AND table_name = 'ash_user_tokens'
      ) THEN
        ALTER TABLE ash_user_tokens DROP CONSTRAINT ash_user_tokens_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'api_tokens_ash_user_id_fkey' AND table_name = 'api_tokens'
      ) THEN
        ALTER TABLE api_tokens DROP CONSTRAINT api_tokens_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'photos_ash_user_id_fkey' AND table_name = 'photos'
      ) THEN
        ALTER TABLE photos DROP CONSTRAINT photos_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'notes_ash_user_id_fkey' AND table_name = 'notes'
      ) THEN
        ALTER TABLE notes DROP CONSTRAINT notes_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    # Step 2: Convert ash_users.id from TEXT to UUID
    # First, ensure all existing IDs are valid UUID format
    execute("""
    UPDATE ash_users
    SET id = CASE
      WHEN id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN id
      ELSE gen_random_uuid()::text
    END
    WHERE id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    """)

    # Convert ash_users.id to UUID type
    execute("""
    ALTER TABLE ash_users
    ALTER COLUMN id TYPE uuid USING id::uuid;
    """)

    # Add default value for new records
    execute("""
    ALTER TABLE ash_users
    ALTER COLUMN id SET DEFAULT uuid_generate_v7();
    """)

    # Step 3: Convert all foreign key columns from TEXT to UUID
    execute("""
    ALTER TABLE ash_user_tokens
    ALTER COLUMN ash_user_id TYPE uuid USING ash_user_id::uuid;
    """)

    execute("""
    ALTER TABLE api_tokens
    ALTER COLUMN ash_user_id TYPE uuid USING ash_user_id::uuid;
    """)

    execute("""
    ALTER TABLE photos
    ALTER COLUMN ash_user_id TYPE uuid USING ash_user_id::uuid;
    """)

    execute("""
    ALTER TABLE notes
    ALTER COLUMN ash_user_id TYPE uuid USING ash_user_id::uuid;
    """)

    # Step 4: Recreate foreign key constraints
    execute("""
    ALTER TABLE ash_user_tokens
    ADD CONSTRAINT ash_user_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE api_tokens
    ADD CONSTRAINT api_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE photos
    ADD CONSTRAINT photos_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE notes
    ADD CONSTRAINT notes_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)
  end

  def down do
    # Drop foreign key constraints
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'ash_user_tokens_ash_user_id_fkey' AND table_name = 'ash_user_tokens'
      ) THEN
        ALTER TABLE ash_user_tokens DROP CONSTRAINT ash_user_tokens_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'api_tokens_ash_user_id_fkey' AND table_name = 'api_tokens'
      ) THEN
        ALTER TABLE api_tokens DROP CONSTRAINT api_tokens_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'photos_ash_user_id_fkey' AND table_name = 'photos'
      ) THEN
        ALTER TABLE photos DROP CONSTRAINT photos_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'notes_ash_user_id_fkey' AND table_name = 'notes'
      ) THEN
        ALTER TABLE notes DROP CONSTRAINT notes_ash_user_id_fkey;
      END IF;
    END $$;
    """)

    # Convert foreign key columns back to TEXT
    execute("""
    ALTER TABLE ash_user_tokens
    ALTER COLUMN ash_user_id TYPE text USING ash_user_id::text;
    """)

    execute("""
    ALTER TABLE api_tokens
    ALTER COLUMN ash_user_id TYPE text USING ash_user_id::text;
    """)

    execute("""
    ALTER TABLE photos
    ALTER COLUMN ash_user_id TYPE text USING ash_user_id::text;
    """)

    execute("""
    ALTER TABLE notes
    ALTER COLUMN ash_user_id TYPE text USING ash_user_id::text;
    """)

    # Convert ash_users.id back to TEXT
    execute("""
    ALTER TABLE ash_users
    ALTER COLUMN id DROP DEFAULT;
    """)

    execute("""
    ALTER TABLE ash_users
    ALTER COLUMN id TYPE text USING id::text;
    """)

    # Recreate foreign key constraints
    execute("""
    ALTER TABLE ash_user_tokens
    ADD CONSTRAINT ash_user_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE api_tokens
    ADD CONSTRAINT api_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE photos
    ADD CONSTRAINT photos_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE notes
    ADD CONSTRAINT notes_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE;
    """)
  end
end
