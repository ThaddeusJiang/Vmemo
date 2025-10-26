defmodule Vmemo.AshRepo.Migrations.MakeUserIdNullableInApiTokens do
  @moduledoc """
  Make user_id nullable in api_tokens to support migration from old system
  """

  use Ecto.Migration

  def up do
    alter table(:api_tokens) do
      modify(:user_id, :integer, null: true)
    end
  rescue
    _ -> :ok
  end

  def down do
    alter table(:api_tokens) do
      modify(:user_id, :integer, null: false)
    end
  rescue
    _ -> :ok
  end
end
