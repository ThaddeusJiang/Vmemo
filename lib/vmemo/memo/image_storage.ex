defmodule Vmemo.Memo.ImageStorage do
  @moduledoc false
  alias SmallSdk.FileSystem
  alias SmallSdk.ImageMagick

  @thumb_sizes %{s: 320, m: 1280}

  def cp_file(src, user_id, filename) do
    dest =
      if tiff_upload?(src, filename) do
        convert_tiff_to_png!(src, gen_dest(user_id, png_filename(filename)))
      else
        FileSystem.cp!(src, gen_dest(user_id, filename))
      end

    {:ok, dest}
  end

  def thumbs!(storage_path) when is_binary(storage_path) do
    ext = Path.extname(storage_path)
    root = Path.rootname(storage_path, ext)

    Enum.each(@thumb_sizes, fn {size, max_side} ->
      thumb_path = "#{root}--#{size}#{ext}"
      ImageMagick.resize_to_fit!(storage_path, thumb_path, max_side)
    end)
  end

  def thumbnail_url(url, size) when size in [:s, :m] and is_binary(url) do
    ext = Path.extname(url)
    root = Path.rootname(url, ext)
    "#{root}--#{size}#{ext}"
  end

  def thumbnail_url(url, _size), do: url

  def storage_path_from_url(url, user_id) when is_binary(url) and not is_nil(user_id) do
    storage_prefix = Path.join(["storage", "v1"]) |> Path.expand()
    parsed = URI.parse(url)
    raw_path = parsed.path || url

    primary =
      raw_path
      |> String.trim_leading("/")
      |> Path.expand()

    fallback =
      raw_path
      |> Path.basename()
      |> then(&Path.join(["storage", "v1", to_string(user_id), "images", &1]))
      |> Path.expand()

    cond do
      String.starts_with?(primary, storage_prefix <> "/") and
        String.contains?(primary, "/images/") and File.exists?(primary) ->
        {:ok, primary}

      String.starts_with?(fallback, storage_prefix <> "/") and File.exists?(fallback) ->
        {:ok, fallback}

      true ->
        {:error, :file_not_found}
    end
  end

  def storage_path_from_url(_, _), do: {:error, :invalid_url}

  defp gen_dest(user_id, filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
    normalized_filename = filename |> to_string() |> String.downcase()

    Path.join([user_id, "images", timestamp <> "_" <> normalized_filename])
  end

  defp convert_tiff_to_png!(src, dest) do
    storage_dest = Path.join(["storage/v1", dest])
    storage_dest |> Path.dirname() |> File.mkdir_p!()
    ImageMagick.convert_to_png!(src, storage_dest)
    storage_dest
  end

  defp png_filename(filename) do
    filename
    |> to_string()
    |> Path.rootname()
    |> Kernel.<>(".png")
  end

  defp tiff_upload?(src, filename) do
    tiff_extension?(filename) or tiff_header?(src)
  end

  defp tiff_extension?(filename) do
    filename
    |> to_string()
    |> Path.extname()
    |> String.downcase()
    |> then(&(&1 in [".tif", ".tiff"]))
  end

  defp tiff_header?(path) when is_binary(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, io} ->
        try do
          case :file.read(io, 4) do
            {:ok, <<"II", marker, 0>>} when marker in [42, 43] -> true
            {:ok, <<"MM", 0, marker>>} when marker in [42, 43] -> true
            _ -> false
          end
        after
          File.close(io)
        end

      {:error, _reason} ->
        false
    end
  end

  defp tiff_header?(_path), do: false
end
