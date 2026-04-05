defmodule Mix.Tasks.Ts.Migrate do
  use Mix.Task

  @shortdoc "Run Typesense migrations"

  @moduledoc """
  Usage:
    mix ts.migrate
    mix ts.migrate --reset
  """

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} = OptionParser.parse(args, strict: [reset: :boolean])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    start_runtime()

    if opts[:reset] do
      reset_typesense()
    end

    Vmemo.Ts.migrate()
    Vmemo.Ts.Warmup.ensure_image_embedding_model_ready()
  end

  defp start_runtime do
    Mix.Task.run("app.start")
    _ = Application.ensure_all_started(:telemetry)

    case Finch.start_link(name: Req.Finch) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  defp reset_typesense do
    Vmemo.Ts.reset()
  end
end
