defmodule Vmemo.Ai.ImagePreprocessor do
  @moduledoc false

  alias SmallSdk.ImageMagick

  @max_side 1536
  @jpeg_quality 85

  def maybe_prepare_for_vision(binary, mime_type)
      when is_binary(binary) and is_binary(mime_type) do
    if skip_preprocess?(binary, mime_type) do
      {:ok, binary}
    else
      resize_with_external_tool(binary, mime_type)
    end
  end

  defp skip_preprocess?(binary, mime_type) do
    byte_size(binary) < 500_000 or mime_type == "image/gif"
  end

  defp resize_with_external_tool(binary, mime_type) do
    result_binary =
      ImageMagick.preprocess_for_vision!(
        binary,
        mime_type,
        max_side: @max_side,
        quality: @jpeg_quality
      )

    if byte_size(result_binary) < byte_size(binary) do
      {:ok, result_binary}
    else
      {:ok, binary}
    end
  end
end
