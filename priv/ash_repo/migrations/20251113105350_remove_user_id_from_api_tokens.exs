defmodule Vmemo.AshRepo.Migrations.RemoveUserIdFromApiTokens do
  use Ecto.Migration

  def up do
    alter table(:api_tokens) do
      remove :user_id
    end
  end

  def down do
    alter table(:api_tokens) do
      add :user_id, :bigint
    end
  end
end
