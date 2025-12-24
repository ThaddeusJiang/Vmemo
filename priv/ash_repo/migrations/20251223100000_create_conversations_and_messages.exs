defmodule Vmemo.AshRepo.Migrations.CreateConversationsAndMessages do
  use Ecto.Migration

  def up do
    # Create conversations table if it doesn't exist
    execute("""
    CREATE TABLE IF NOT EXISTS conversations (
      id uuid NOT NULL DEFAULT uuid_generate_v7() PRIMARY KEY,
      title text,
      user_id uuid NOT NULL REFERENCES ash_users(id) ON DELETE CASCADE,
      inserted_at timestamp(6) NOT NULL,
      updated_at timestamp(6) NOT NULL
    );
    """)

    # Create indexes if they don't exist
    execute("""
    CREATE INDEX IF NOT EXISTS conversations_user_id_index ON conversations(user_id);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS conversations_inserted_at_index ON conversations(inserted_at);
    """)

    # Create messages table if it doesn't exist
    execute("""
    CREATE TABLE IF NOT EXISTS messages (
      id uuid NOT NULL DEFAULT uuid_generate_v7() PRIMARY KEY,
      text text NOT NULL,
      tool_calls jsonb[],
      tool_results jsonb[],
      source text NOT NULL DEFAULT 'user',
      complete boolean NOT NULL DEFAULT true,
      conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      response_to_id uuid REFERENCES messages(id) ON DELETE CASCADE,
      inserted_at timestamp(6) NOT NULL,
      updated_at timestamp(6) NOT NULL
    );
    """)

    # Create indexes if they don't exist
    execute("""
    CREATE INDEX IF NOT EXISTS messages_conversation_id_index ON messages(conversation_id);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS messages_response_to_id_index ON messages(response_to_id);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS messages_inserted_at_index ON messages(inserted_at);
    """)
  end

  def down do
    drop table(:messages)
    drop table(:conversations)
  end
end
