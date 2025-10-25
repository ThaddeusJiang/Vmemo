defmodule Vmemo.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    # API Tokens 表（安全存储）
    create table(:api_tokens) do
      add :token_hash, :string, null: false  # 只存储 token 的 hash
      add :name, :string, null: false
      add :description, :text
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :is_active, :boolean, default: true, null: false
      add :created_at, :utc_datetime  # 创建时间，用于 token 显示
      add :user_id, references(:account_users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:api_tokens, [:token_hash])
    create index(:api_tokens, [:user_id])
    create index(:api_tokens, [:expires_at])
    create index(:api_tokens, [:is_active])

  end
end
