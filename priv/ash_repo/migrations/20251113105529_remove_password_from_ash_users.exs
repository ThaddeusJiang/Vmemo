defmodule Vmemo.AshRepo.Migrations.RemovePasswordFromAshUsers do
  use Ecto.Migration

  def up do
    alter table(:ash_users) do
      remove :password
    end
  end

  def down do
    alter table(:ash_users) do
      add :password, :text
    end
  end
end
