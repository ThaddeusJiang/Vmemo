defmodule Vmemo.AshRepo.Migrations.AddAshAuthenticationOnly do
  @moduledoc """
  Adds only Ash Authentication tables
  """

  use Ecto.Migration

  def up do
    # 创建 ash_users 表
    create table(:ash_users, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :email, :text, null: false
      add :password, :text
      add :hashed_password, :text, null: false
      add :confirmed_at, :utc_datetime
      add :display_name, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ash_users, [:email], name: "ash_users_unique_email_index")

    # 创建 ash_user_tokens 表
    create table(:ash_user_tokens, primary_key: false) do
      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :extra_data, :map
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :subject, :text, null: false
      add :jti, :text, null: false, primary_key: true
      add :aud, :text, null: false
      add :exp, :utc_datetime, null: false
      add :iss, :text, null: false
      add :sub, :text, null: false
      add :typ, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :ash_user_id,
          references(:ash_users,
            column: :id,
            name: "ash_user_tokens_ash_user_id_fkey",
            type: :uuid,
            prefix: "public"
          )
    end

    # 为 api_tokens 表添加 ash_user_id 列
    # 注意：只在表存在时添加
    # alter table(:api_tokens) do
    #   add :ash_user_id,
    #       references(:ash_users,
    #         column: :id,
    #         name: "api_tokens_ash_user_id_fkey",
    #         type: :uuid,
    #         prefix: "public"
    #       )
    # end
  end

  def down do
    # 删除 api_tokens 表的 ash_user_id 外键
    # drop_if_exists constraint(:api_tokens, "api_tokens_ash_user_id_fkey")
    # alter table(:api_tokens) do
    #   remove :ash_user_id
    # end

    # 删除 ash_user_tokens 表
    drop constraint(:ash_user_tokens, "ash_user_tokens_ash_user_id_fkey")
    drop table(:ash_user_tokens)

    # 删除 ash_users 表
    drop_if_exists unique_index(:ash_users, [:email], name: "ash_users_unique_email_index")
    drop table(:ash_users)
  end
end
