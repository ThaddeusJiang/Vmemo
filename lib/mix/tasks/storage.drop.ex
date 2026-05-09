defmodule Mix.Tasks.Storage.Drop do
  use Mix.Task

  @shortdoc "Drop and recreate local storage directory"

  @moduledoc """
  Usage:
    mix storage.drop
  """

  @impl Mix.Task
  def run(_args) do
    storage_root = Path.join(["storage", "v1"])

    File.rm_rf!(storage_root)
    File.mkdir_p!(storage_root)

    Mix.shell().info("storage reset: #{storage_root}")
  end
end
