defmodule Vmemo.Ts.SchemaMigrator do
  @moduledoc false

  @migrations_collection "ts_schema_migrations"

  def migrate do
    migrations_collection = migrations_collection()

    Vmemo.Ts.Schema.ensure_migrations_collection(migrations_collection)
    applied_versions = Vmemo.Ts.Schema.applied_migration_versions(migrations_collection)

    migration_entries()
    |> validate_unique_migration_versions()
    |> pending_migrations(applied_versions)
    |> Enum.each(fn %{version: version, path: path} ->
      Code.eval_file(path)
      Vmemo.Ts.Schema.record_migration_version(migrations_collection, version)
    end)

    :ok
  end

  def pending_migrations(migration_entries, applied_versions) do
    applied_versions = MapSet.new(applied_versions)

    migration_entries
    |> Enum.sort_by(& &1.version)
    |> Enum.reject(fn %{version: version} -> MapSet.member?(applied_versions, version) end)
  end

  def validate_unique_migration_versions(entries) do
    versions = Enum.map(entries, & &1.version)

    case versions -- Enum.uniq(versions) do
      [] ->
        entries

      duplicated ->
        duplicated_versions =
          duplicated
          |> Enum.uniq()
          |> Enum.sort()
          |> Enum.join(", ")

        raise("Typesense migration versions must be unique: #{duplicated_versions}")
    end
  end

  def migrations_collection do
    @migrations_collection
  end

  defp migration_entries do
    migrations_glob()
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn path ->
      %{
        version: Path.basename(path, ".exs"),
        path: path
      }
    end)
  end

  defp migrations_glob, do: Path.join(migrations_dir(), "*.exs")

  defp migrations_dir, do: Application.app_dir(:vmemo, "priv/ts/migrations")
end
