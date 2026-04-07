defmodule Vmemo.Release do
  @moduledoc """
  Release tasks for database and Typesense migrations.
  """

  @app :vmemo

  @doc """
  Run all release migrations.

  This includes:
  - AshPostgres repo migrations
  - Typesense migrations
  """
  def migrate do
    ash_migrate()
    ts_migrate()
  end

  @doc """
  Run all AshPostgres release migrations for configured repos.
  """
  def ash_migrate do
    load_app()

    Enum.each(repos(), &run_repo_migrations/1)
  end

  defp run_repo_migrations(repo) do
    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        Enum.each(migration_paths(repo), fn path ->
          Ecto.Migrator.run(repo, path, :up, all: true)
        end)
      end)
  end

  @doc """
  Run Typesense migrations.
  """
  def ts_migrate do
    load_app()

    _ = Application.ensure_all_started(:telemetry)
    _ = Application.ensure_all_started(@app)
    _ = ensure_req_finch_started()

    load_ts_schema_modules()
    apply(ts_schema_migrator_module(), :migrate, [])
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp ensure_req_finch_started do
    case Finch.start_link(name: Req.Finch) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp load_ts_schema_modules do
    ts_dir = Application.app_dir(@app, "priv/ts")
    Code.require_file("schema.exs", ts_dir)
    Code.require_file("schema_migrator.exs", ts_dir)
  end

  defp ts_schema_migrator_module, do: Module.concat([Vmemo, Ts, SchemaMigrator])

  defp migration_paths(repo) do
    path = Application.app_dir(@app, "priv/#{repo_migrations_path(repo)}/migrations")

    if File.dir?(path), do: [path], else: []
  end

  defp repo_migrations_path(repo) do
    repo
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
