defmodule Vmemo.Ts.SchemaMigratorTest do
  use ExUnit.Case, async: true

  setup_all do
    ts_dir = Application.app_dir(:vmemo, "priv/ts")
    Code.require_file("schema.exs", ts_dir)
    Code.require_file("schema_migrator.exs", ts_dir)
    :ok
  end

  describe "pending_migrations/2" do
    test "returns migrations not present in applied versions, ordered by version" do
      entries = [
        %{version: "2025-01-27", path: "priv/ts/migrations/2025-01-27.exs"},
        %{version: "2024-12-19", path: "priv/ts/migrations/2024-12-19.exs"},
        %{version: "2024-12-20", path: "priv/ts/migrations/2024-12-20.exs"}
      ]

      applied_versions = ["2024-12-19"]

      assert [
               %{version: "2024-12-20"},
               %{version: "2025-01-27"}
             ] = Vmemo.Ts.SchemaMigrator.pending_migrations(entries, applied_versions)
    end

    test "returns empty list when all versions are already applied" do
      entries = [
        %{version: "2024-12-19", path: "priv/ts/migrations/2024-12-19.exs"},
        %{version: "2024-12-20", path: "priv/ts/migrations/2024-12-20.exs"}
      ]

      applied_versions = ["2024-12-19", "2024-12-20"]

      assert [] = Vmemo.Ts.SchemaMigrator.pending_migrations(entries, applied_versions)
    end
  end

  describe "validate_unique_migration_versions/1" do
    test "returns entries when versions are unique" do
      entries = [
        %{version: "2024-12-19", path: "a"},
        %{version: "2024-12-20", path: "b"}
      ]

      assert entries == Vmemo.Ts.SchemaMigrator.validate_unique_migration_versions(entries)
    end

    test "raises when duplicated migration versions exist" do
      entries = [
        %{version: "2024-12-19", path: "a"},
        %{version: "2024-12-19", path: "b"}
      ]

      assert_raise RuntimeError, ~r/Typesense migration versions must be unique/, fn ->
        Vmemo.Ts.SchemaMigrator.validate_unique_migration_versions(entries)
      end
    end
  end
end
