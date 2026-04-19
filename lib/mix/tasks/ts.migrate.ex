defmodule Mix.Tasks.Ts.Migrate do
  use Mix.Task

  @shortdoc "Run Typesense migrations"

  @moduledoc """
  Usage:
    mix ts.migrate
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    _ = Application.ensure_all_started(:telemetry)

    case Finch.start_link(name: Req.Finch) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    load_ts_schema_modules()
    apply(ts_schema_migrator_module(), :migrate, [])
  end

  defp load_ts_schema_modules do
    ts_dir = Application.app_dir(:vmemo, "priv/ts")
    Code.require_file("schema.exs", ts_dir)
    Code.require_file("schema_migrator.exs", ts_dir)
  end

  defp ts_schema_migrator_module, do: Module.concat([Vmemo, Ts, SchemaMigrator])
end
