defmodule Vmemo.Ai.Caption do
  @moduledoc false

  alias SmallSdk.Moondream

  def generate_caption(image_base64) do
    with {:ok, caption} <- Moondream.caption(image_base64) do
      {:ok, caption}
    else
      {:error, reason} ->
        handle_caption_error(reason)
    end
  rescue
    e -> {:error, e}
  end

  defp handle_caption_error(:file_not_found), do: {:discard, :file_not_found}
  defp handle_caption_error("Request failed with status 401"), do: {:discard, "Request failed with status 401"}
  defp handle_caption_error("Request failed with status 403"), do: {:discard, "Request failed with status 403"}
  defp handle_caption_error("Request failed with status 404"), do: {:discard, "Request failed with status 404"}
  defp handle_caption_error(reason), do: {:error, reason}
end
