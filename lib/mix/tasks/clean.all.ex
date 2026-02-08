defmodule Mix.Tasks.Clean.All do
  @shortdoc "Remove all generated and local data (_build, deps, _data, storage, tmp, cover)"
  @moduledoc """
  Deletes temporary and generated directories so the project is back to a clean state.
  After running, use `mix setup` to restore deps and database.

  Removes:
    - _build   (compile output)
    - deps     (dependencies)
    - _data    (docker volume data: pg-data, ts-data)
    - storage  (uploaded files)
    - tmp      (project temp files)
    - cover    (test coverage, if present)
  """

  use Mix.Task

  @dirs ~w(_build deps _data storage tmp cover)

  @impl Mix.Task
  def run(_args) do
    root = File.cwd!()

    for name <- @dirs do
      path = Path.join(root, name)
      if File.exists?(path) do
        File.rm_rf!(path)
        Mix.shell().info("Removed #{path}")
      end
    end
  end
end
