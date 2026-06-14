defmodule SmallSdk.FileSystem do
  @moduledoc """
  A module to interact with the file system.

  naming reference: Expo.dev FileSystem
  """

  alias Vmemo.Storage

  def cp!(src, dest) do
    dest = Storage.path(["v1", dest])

    dest_dir = Path.dirname(dest)

    File.mkdir_p!(dest_dir)

    File.cp!(src, dest)

    dest
  end

  def read_image_base64(file_path) do
    case File.read(file_path) do
      {:ok, content} -> Base.encode64(content)
      {:error, _reason} -> nil
    end
  end

  def read_image_base64!(file_path) do
    file_path
    |> File.read!()
    |> Base.encode64()
  end
end
