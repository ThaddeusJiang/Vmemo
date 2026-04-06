defmodule Vmemo.Ts do
  @moduledoc false

  defdelegate change_1(), to: Vmemo.Ts.Collections
  defdelegate change_2(), to: Vmemo.Ts.Collections
  defdelegate change_3(), to: Vmemo.Ts.Collections
  defdelegate change_4(), to: Vmemo.Ts.Collections
  defdelegate reset(), to: Vmemo.Ts.Collections

  defdelegate migrate(), to: Vmemo.Ts.Migrations
  defdelegate pending_migrations(migration_entries, applied_versions), to: Vmemo.Ts.Migrations
  defdelegate validate_unique_migration_versions(entries), to: Vmemo.Ts.Migrations
end
