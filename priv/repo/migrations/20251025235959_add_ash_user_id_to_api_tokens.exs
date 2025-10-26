defmodule Vmemo.Repo.Migrations.AddAshUserIdToApiTokens do
  use Ecto.Migration

  def change do
    alter table(:api_tokens) do
      add :ash_user_id, :uuid
    end

    create index(:api_tokens, [:ash_user_id])
  end
end
