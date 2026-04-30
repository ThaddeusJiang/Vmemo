defmodule SmallSdk.ImageMagick do
  @moduledoc false

  def rotate_90_clockwise!(path) when is_binary(path) do
    {tool, use_magick_entrypoint?} = pick_tool!()
    ext = Path.extname(path)
    unique = System.unique_integer([:positive, :monotonic])
    out_path = Path.join(Path.dirname(path), ".rotate-#{unique}#{ext}")
    previous_mtime = File.stat!(path, time: :posix).mtime

    try do
      args = build_rotate_args(use_magick_entrypoint?, path, out_path)
      {_output, status} = System.cmd(tool, args, stderr_to_stdout: true)

      case status do
        0 ->
          File.rename!(out_path, path)
          # Last-Modified is second-precision in HTTP. Ensure mtime always advances
          # across rapid consecutive rotations so cache revalidation can detect changes.
          next_mtime = max(System.os_time(:second) + 1, previous_mtime + 1)
          File.touch!(path, next_mtime)
          :ok

        _ ->
          raise "ImageMagick rotate command failed with exit status #{status}."
      end
    after
      _ = File.rm(out_path)
    end
  end

  def preprocess_for_vision!(binary, mime_type, opts \\ [])
      when is_binary(binary) and is_binary(mime_type) and is_list(opts) do
    max_side = Keyword.get(opts, :max_side, 1536)
    quality = Keyword.get(opts, :quality, 85)

    {tool, use_magick_entrypoint?} = pick_tool!()
    in_ext = extension_for_mime(mime_type)
    out_ext = output_extension_for_mime(mime_type)
    in_path = temp_path("vision-in", in_ext)
    out_path = temp_path("vision-out", out_ext)

    try do
      File.write!(in_path, binary)
      args = build_args(use_magick_entrypoint?, in_path, out_path, mime_type, max_side, quality)
      {_output, status} = System.cmd(tool, args, stderr_to_stdout: true)

      case status do
        0 -> File.read!(out_path)
        _ -> raise "ImageMagick command failed with exit status #{status}."
      end
    after
      _ = File.rm(in_path)
      _ = File.rm(out_path)
    end
  end

  defp pick_tool! do
    cond do
      executable?("magick") -> {"magick", true}
      executable?("convert") -> {"convert", false}
      true -> raise "ImageMagick executable is required but not found (magick/convert)."
    end
  end

  defp executable?(name) do
    name |> String.to_charlist() |> :os.find_executable() != false
  end

  defp build_args(true, in_path, out_path, mime_type, max_side, quality) do
    ["convert" | build_convert_args(in_path, out_path, mime_type, max_side, quality)]
  end

  defp build_args(false, in_path, out_path, mime_type, max_side, quality) do
    build_convert_args(in_path, out_path, mime_type, max_side, quality)
  end

  defp build_rotate_args(true, in_path, out_path) do
    ["convert", in_path, "-auto-orient", "-rotate", "90", out_path]
  end

  defp build_rotate_args(false, in_path, out_path) do
    [in_path, "-auto-orient", "-rotate", "90", out_path]
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
