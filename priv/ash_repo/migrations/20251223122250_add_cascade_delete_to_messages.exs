defmodule Vmemo.AshRepo.Migrations.AddCascadeDeleteToMessages do
  use Ecto.Migration

  def up do
    # Drop existing foreign key constraints
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'messages_conversation_id_fkey' AND table_name = 'messages'
      ) THEN
        ALTER TABLE messages DROP CONSTRAINT messages_conversation_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'messages_response_to_id_fkey' AND table_name = 'messages'
      ) THEN
        ALTER TABLE messages DROP CONSTRAINT messages_response_to_id_fkey;
      END IF;
    END $$;
    """)

    # Recreate with CASCADE delete
    execute("""
    ALTER TABLE messages
    ADD CONSTRAINT messages_conversation_id_fkey
    FOREIGN KEY (conversation_id)
    REFERENCES conversations(id)
    ON DELETE CASCADE;
    """)

    execute("""
    ALTER TABLE messages
    ADD CONSTRAINT messages_response_to_id_fkey
    FOREIGN KEY (response_to_id)
    REFERENCES messages(id)
    ON DELETE CASCADE;
    """)
  end

  def down do
    # Drop CASCADE constraints
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'messages_conversation_id_fkey' AND table_name = 'messages'
      ) THEN
        ALTER TABLE messages DROP CONSTRAINT messages_conversation_id_fkey;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'messages_response_to_id_fkey' AND table_name = 'messages'
      ) THEN
        ALTER TABLE messages DROP CONSTRAINT messages_response_to_id_fkey;
      END IF;
    END $$;
    """)

    # Recreate with NO ACTION (default)
    execute("""
    ALTER TABLE messages
    ADD CONSTRAINT messages_conversation_id_fkey
    FOREIGN KEY (conversation_id)
    REFERENCES conversations(id)
    ON DELETE NO ACTION;
    """)

    execute("""
    ALTER TABLE messages
    ADD CONSTRAINT messages_response_to_id_fkey
    FOREIGN KEY (response_to_id)
    REFERENCES messages(id)
    ON DELETE NO ACTION;
    """)
  end
end
