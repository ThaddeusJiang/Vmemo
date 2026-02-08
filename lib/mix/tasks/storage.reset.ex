defmodule Mix.Tasks.Storage.Reset do
  @shortdoc "Remove local storage directory (uploaded files)"
  @moduledoc """
  Deletes the project `storage/` directory so that `mix reset` clears
  DB, Typesense, and local uploads (same dir as docker volume ./storage:/app/storage).
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    root = File.cwd!()
    path = Path.join(root, "storage")

    if File.exists?(path) do
      File.rm_rf!(path)
      Mix.shell().info("Removed #{path}")
    else
      Mix.shell().info("No storage dir at #{path}")
    end
  end
end
