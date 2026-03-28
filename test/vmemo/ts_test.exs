defmodule Vmemo.TsTest do
  use ExUnit.Case, async: true

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
             ] = Vmemo.Ts.pending_migrations(entries, applied_versions)
    end

    test "returns empty list when all versions are already applied" do
      entries = [
        %{version: "2024-12-19", path: "priv/ts/migrations/2024-12-19.exs"},
        %{version: "2024-12-20", path: "priv/ts/migrations/2024-12-20.exs"}
      ]

      applied_versions = ["2024-12-19", "2024-12-20"]

      assert [] = Vmemo.Ts.pending_migrations(entries, applied_versions)
    end
  end
end
