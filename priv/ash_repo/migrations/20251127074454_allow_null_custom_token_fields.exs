defmodule Vmemo.AshRepo.Migrations.AllowNullCustomTokenFields do
  use Ecto.Migration

  def change do
    alter table(:ash_user_tokens) do
      modify :aud, :text, null: true
      modify :exp, :utc_datetime, null: true
      modify :iss, :text, null: true
      modify :sub, :text, null: true
      modify :typ, :text, null: true
    end
  end
end
