defmodule Vmemo.Repo.Migrations.MigrateToAshAuthentication do
  use Ecto.Migration

  def up do
    drop table(:account_users_tokens)

    create table(:account_users_tokens, primary_key: false) do
      add :jti, :text, null: false, primary_key: true
      add :subject, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :purpose, :text, null: false
      add :extra_data, :map

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end

  def down do
    drop table(:account_users_tokens)

    create table(:account_users_tokens) do
      add :user_id, references(:account_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:account_users_tokens, [:user_id])
    create unique_index(:account_users_tokens, [:context, :token])
  end
end
