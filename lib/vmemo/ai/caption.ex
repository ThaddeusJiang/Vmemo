defmodule Vmemo.Ai.Caption do
  @moduledoc false
  require Logger

  alias SmallSdk.FileSystem
  alias SmallSdk.Moondream

  def generate_caption_from_url(url) do
    with {:ok, image_base64} <- read_image_base64(url),
         {:ok, caption} <- Moondream.caption(image_base64) do
      {:ok, caption}
    else
      {:error, :file_not_found} ->
        {:discard, :file_not_found}

      {:error, reason} ->
        if discard_caption_error?(reason) do
          {:discard, reason}
        else
          {:error, reason}
        end
    end
  rescue
    e -> {:error, e}
  end

  def gen_description(image_path) do
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

  def gen_description!(image_path) do
    case gen_description(image_path) do
      {:ok, description} -> description
      {:error, error} -> raise "Failed to generate description: #{inspect(error)}"
    end
  end

  defp read_image_base64(url) do
    file_path =
      url
      |> String.trim_leading("/")
      |> String.trim_leading("storage/v1/")
      |> then(&Path.join(["storage", "v1", &1]))

    case FileSystem.read_image_base64(file_path) do
      nil -> {:error, :file_not_found}
      image_base64 -> {:ok, image_base64}
    end
  end

  defp discard_caption_error?(:connection_refused), do: true
  defp discard_caption_error?(:timeout), do: true
  defp discard_caption_error?(%Req.TransportError{}), do: true
  defp discard_caption_error?("Request failed with status 401"), do: true
  defp discard_caption_error?("Request failed with status 403"), do: true
  defp discard_caption_error?("Request failed with status 404"), do: true
  defp discard_caption_error?(_), do: false
end
