defmodule Mix.Tasks.Ts.Drop do
  use Mix.Task

  @shortdoc "Drop Typesense collections"
  @moduledoc false

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    _ = Application.ensure_all_started(:telemetry)

    case Finch.start_link(name: Req.Finch) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Vmemo.Ts.reset()
  end
end
