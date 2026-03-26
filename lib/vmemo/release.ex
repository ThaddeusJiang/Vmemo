defmodule Vmemo.Release do
  @moduledoc """
  Release tasks for database and Typesense migrations.
  """

  @app :vmemo

  @doc """
  Run all Ecto migrations for configured repos.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          for path <- migration_paths(repo) do
            Ecto.Migrator.run(repo, path, :up, all: true)
          end
        end)
    end
  end

  @doc """
  Run Typesense migrations.
  """
  def ts_migrate do
    load_app()

    _ = Application.ensure_all_started(:telemetry)
    _ = Application.ensure_all_started(@app)
    _ = ensure_req_finch_started()

    Vmemo.Ts.migrate()
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

  defp migration_paths(repo) do
    default_path = Application.app_dir(@app, "priv/#{repo_migrations_path(repo)}/migrations")
    legacy_path = Application.app_dir(@app, "priv/repo/migrations")

    [default_path, legacy_path]
    |> Enum.uniq()
    |> Enum.filter(&File.dir?/1)
  end

  defp repo_migrations_path(repo) do
    repo
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
