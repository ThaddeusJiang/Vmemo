defmodule Vmemo.AshRepo.Migrations.FixPhotosIdColumnToUuid do
  use Ecto.Migration

  def up do
    # This migration is now redundant as the main migration (20251029130000_squashed_core_schema.exs)
    # already creates tables with correct UUID types for IDs and TEXT types for user_id fields.
    # This migration is kept for historical purposes but does nothing.
    :ok
  end

  def down do
    # This migration is now redundant as the main migration (20251029130000_squashed_core_schema.exs)
    # already creates tables with correct UUID types for IDs and TEXT types for user_id fields.
    # This migration is kept for historical purposes but does nothing.
    :ok
  end
end
