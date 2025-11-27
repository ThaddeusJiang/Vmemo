defmodule Vmemo.PhotoService.Ai do
  require Logger

  alias SmallSdk.FileSystem
  alias SmallSdk.Moondream

  def gen_description(image_path) do
    try do
      image_base64 = FileSystem.read_image_base64(Path.join([".", image_path]))

      if image_base64 == nil do
        {:error, "Failed to read image file"}
      else
        case Moondream.caption(image_base64) do
          {:ok, caption} -> {:ok, caption}
          {:error, reason} -> {:error, reason}
        end
      end
    rescue
      e -> {:error, e}
    end
  end

  def gen_description!(image_path) do
    case gen_description(image_path) do
      {:ok, description} -> description
      {:error, error} -> raise "Failed to generate description: #{inspect(error)}"
    end
  end
end
