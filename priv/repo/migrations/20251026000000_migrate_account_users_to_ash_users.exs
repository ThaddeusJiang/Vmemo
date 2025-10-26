defmodule Vmemo.Repo.Migrations.MigrateAccountUsersToAshUsers do
  use Ecto.Migration

  def up do
    # 迁移 account_users 数据到 ash_users
    execute """
    INSERT INTO ash_users (id, email, hashed_password, confirmed_at, display_name, inserted_at, updated_at)
    SELECT
      gen_random_uuid() as id,
      email,
      hashed_password,
      confirmed_at,
      COALESCE(display_name, split_part(email, '@', 1)) as display_name,
      inserted_at,
      updated_at
    FROM account_users
    WHERE email NOT IN (SELECT email FROM ash_users)
    """

    # 更新 api_tokens 表，将 user_id 关联到新的 ash_user_id
    execute """
    UPDATE api_tokens
    SET ash_user_id = (
      SELECT au.id
      FROM ash_users au
      WHERE au.email = (
        SELECT ac.email
        FROM account_users ac
        WHERE ac.id = api_tokens.user_id
      )
    )
    WHERE user_id IS NOT NULL
    AND ash_user_id IS NULL
    """

    # 显示迁移结果
    execute """
    DO $$
    DECLARE
        account_users_count INTEGER;
        ash_users_count INTEGER;
        migrated_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO account_users_count FROM account_users;
        SELECT COUNT(*) INTO ash_users_count FROM ash_users;
        SELECT COUNT(*) INTO migrated_count FROM api_tokens WHERE ash_user_id IS NOT NULL;

        RAISE NOTICE 'Migration completed:';
        RAISE NOTICE '  Account users: %', account_users_count;
        RAISE NOTICE '  Ash users: %', ash_users_count;
        RAISE NOTICE '  API tokens with ash_user_id: %', migrated_count;
    END $$;
    """
  end

  def down do
    # 回滚迁移 - 删除从 account_users 迁移的数据
    execute """
    DELETE FROM ash_users
    WHERE email IN (
      SELECT email FROM account_users
    )
    """

    # 清除 api_tokens 的 ash_user_id
    execute """
    UPDATE api_tokens
    SET ash_user_id = NULL
    WHERE ash_user_id IS NOT NULL
    """
  end
end
