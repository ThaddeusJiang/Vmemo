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

    Vmemo.Ts.migrate()
    Vmemo.Ts.Warmup.ensure_image_embedding_model_ready()
  end
end
