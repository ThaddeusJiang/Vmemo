defmodule Vmemo.Ai.ImagePreprocessor do
  @moduledoc false

  require Logger

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
    with {:ok, tool} <- pick_tool(),
         {:ok, result_binary} <- run_resize_command(tool, binary, mime_type) do
      if byte_size(result_binary) < byte_size(binary) do
        {:ok, result_binary}
      else
        {:ok, binary}
      end
    else
      {:error, reason} ->
        Logger.debug("Image preprocess skipped: #{inspect(reason)}")
        {:ok, binary}
    end
  end

  defp pick_tool do
    cond do
      executable?("magick") -> {:ok, {"magick", true}}
      executable?("convert") -> {:ok, {"convert", false}}
      true -> {:error, :imagemagick_not_found}
    end
  end

  defp executable?(name) do
    name |> String.to_charlist() |> :os.find_executable() != false
  end

  defp run_resize_command({tool, use_magick_entrypoint?}, binary, mime_type) do
    in_ext = extension_for_mime(mime_type)
    out_ext = output_extension_for_mime(mime_type)
    in_path = temp_path("vision-in", in_ext)
    out_path = temp_path("vision-out", out_ext)

    try do
      :ok = File.write!(in_path, binary)

      args =
        build_args(
          use_magick_entrypoint?,
          in_path,
          out_path,
          mime_type,
          @max_side,
          @jpeg_quality
        )

      {_, status} = System.cmd(tool, args, stderr_to_stdout: true)

      case status do
        0 -> File.read(out_path)
        _ -> {:error, {:convert_failed, status}}
      end
    rescue
      e -> {:error, Exception.message(e)}
    after
      _ = File.rm(in_path)
      _ = File.rm(out_path)
    end
  end

  defp build_args(true, in_path, out_path, mime_type, max_side, quality) do
    ["convert" | build_convert_args(in_path, out_path, mime_type, max_side, quality)]
  end

  defp build_args(false, in_path, out_path, mime_type, max_side, quality) do
    build_convert_args(in_path, out_path, mime_type, max_side, quality)
  end

  defp build_convert_args(in_path, out_path, mime_type, max_side, quality) do
    common = [in_path, "-auto-orient", "-resize", "#{max_side}x#{max_side}>", "-strip"]

    case mime_type do
      "image/jpeg" ->
        common ++ ["-quality", to_string(quality), out_path]

      "image/webp" ->
        common ++ ["-quality", to_string(quality), out_path]

      "image/png" ->
        common ++
          [
            "-define",
            "png:compression-level=9",
            "-define",
            "png:compression-filter=5",
            "-define",
            "png:compression-strategy=1",
            out_path
          ]

      _ ->
        common ++ [out_path]
    end
  end

  defp extension_for_mime("image/png"), do: "png"
  defp extension_for_mime("image/gif"), do: "gif"
  defp extension_for_mime("image/webp"), do: "webp"
  defp extension_for_mime(_), do: "jpg"

  defp output_extension_for_mime("image/png"), do: "png"
  defp output_extension_for_mime("image/webp"), do: "webp"
  defp output_extension_for_mime(_), do: "jpg"

  defp temp_path(prefix, ext) do
    unique = System.unique_integer([:positive, :monotonic])
    Path.join(System.tmp_dir!(), "#{prefix}-#{unique}.#{ext}")
  end
end
