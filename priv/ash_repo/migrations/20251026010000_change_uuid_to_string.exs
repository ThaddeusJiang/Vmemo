defmodule Vmemo.AshRepo.Migrations.ChangeUuidToString do
  @moduledoc """
  Changes UUID types to String types for ash_users and api_tokens tables
  """

  use Ecto.Migration

  def up do
    # 先删除所有外键约束
    execute("""
    ALTER TABLE ash_user_tokens DROP CONSTRAINT IF EXISTS ash_user_tokens_ash_user_id_fkey
    """)

    # 修改 ash_users 表的 id 从 UUID 改为 TEXT
    execute("""
    ALTER TABLE ash_users ALTER COLUMN id TYPE text USING id::text
    """)

    # 删除旧的 UUID 默认值
    execute("""
    ALTER TABLE ash_users ALTER COLUMN id DROP DEFAULT
    """)

    # 修改 api_tokens 表的 ash_user_id 从 UUID 改为 TEXT (if column exists)
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'api_tokens' AND column_name = 'ash_user_id'
      ) THEN
        ALTER TABLE api_tokens ALTER COLUMN ash_user_id TYPE text;
        
        ALTER TABLE api_tokens
        ADD CONSTRAINT api_tokens_ash_user_id_fkey
        FOREIGN KEY (ash_user_id)
        REFERENCES ash_users(id)
        ON DELETE CASCADE;
      END IF;
    END $$;
    """)

    # 修改 ash_user_tokens 表的 ash_user_id
    execute("""
    ALTER TABLE ash_user_tokens
    ALTER COLUMN ash_user_id TYPE text USING ash_user_id::text
    """)

    execute("""
    ALTER TABLE ash_user_tokens
    ADD CONSTRAINT ash_user_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE
    """)
  end

  def down do
    # 逆操作：改回 UUID 类型
    execute("""
    ALTER TABLE ash_user_tokens
    DROP CONSTRAINT IF EXISTS ash_user_tokens_ash_user_id_fkey
    """)

    execute("""
    ALTER TABLE ash_user_tokens
    ALTER COLUMN ash_user_id TYPE uuid USING ash_user_id::uuid
    """)

    execute("""
    ALTER TABLE ash_user_tokens
    ADD CONSTRAINT ash_user_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE
    """)

    # Revert api_tokens if column exists
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'api_tokens' AND column_name = 'ash_user_id'
      ) THEN
        ALTER TABLE api_tokens DROP CONSTRAINT IF EXISTS api_tokens_ash_user_id_fkey;
        ALTER TABLE api_tokens ALTER COLUMN ash_user_id TYPE uuid USING ash_user_id::uuid;
        ALTER TABLE api_tokens
        ADD CONSTRAINT api_tokens_ash_user_id_fkey
        FOREIGN KEY (ash_user_id)
        REFERENCES ash_users(id)
        ON DELETE CASCADE;
      END IF;
    END $$;
    """)

    execute("""
    ALTER TABLE ash_users
    ALTER COLUMN id TYPE uuid USING id::uuid,
    ALTER COLUMN id SET DEFAULT gen_random_uuid()
    """)
  end
end
