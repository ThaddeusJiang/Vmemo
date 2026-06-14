defmodule Vmemo.Memo.ImageStorage do
  @moduledoc false
  alias SmallSdk.FileSystem
  alias SmallSdk.ImageMagick

  @legacy_thumb_sizes %{s: 320, m: 1280}
  @responsive_widths [160, 320, 640, 1280, 1920]
  @sizes %{
    thumb: "96px",
    grid: "(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw",
    detail: "(max-width: 768px) 100vw, 640px",
    full: "100vw"
  }

  def cp_file(src, user_id, filename) do
    dest = FileSystem.cp!(src, gen_dest(user_id, filename))
    {:ok, dest}
  end

  def thumbs!(storage_path) when is_binary(storage_path) do
    ext = Path.extname(storage_path)
    root = Path.rootname(storage_path, ext)

    Enum.each(@legacy_thumb_sizes, fn {size, max_side} ->
      thumb_path = "#{root}--#{size}#{ext}"
      resize_to_fit_atomic!(storage_path, thumb_path, max_side)
    end)

    Enum.each(@responsive_widths, fn width ->
      variant_path = "#{root}--#{width}w#{ext}"
      resize_to_fit_atomic!(storage_path, variant_path, width)
    end)
  end

  def ensure_thumbnail_for_request(original_path, requested_path)
      when is_binary(original_path) and is_binary(requested_path) do
    with {:ok, max_side} <- thumbnail_max_side(requested_path) do
      resize_to_fit_atomic!(original_path, requested_path, max_side)
      {:ok, requested_path}
    end
  rescue
    error -> {:error, error}
  end

  def thumbnail_url(url, size) when size in [:s, :m] and is_binary(url) do
    ext = Path.extname(url)
    root = Path.rootname(url, ext)
    "#{root}--#{size}#{ext}"
  end

  def thumbnail_url(url, width) when width in @responsive_widths and is_binary(url) do
    if storage_image_url?(url), do: variant_url(url, width), else: url
  end

  def thumbnail_url(url, _size), do: url

  def srcset(url) when is_binary(url) do
    if storage_image_url?(url) do
      @responsive_widths
      |> Enum.map_join(", ", fn width -> "#{variant_url(url, width)} #{width}w" end)
    end
  end

  def srcset(_), do: nil

  def sizes(usage) when is_map_key(@sizes, usage), do: Map.fetch!(@sizes, usage)
  def sizes(_), do: Map.fetch!(@sizes, :grid)

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

  defp thumbnail_max_side(path) do
    ext = Path.extname(path)
    root = Path.rootname(path, ext)

    cond do
      String.ends_with?(root, "--s") -> {:ok, Map.fetch!(@legacy_thumb_sizes, :s)}
      String.ends_with?(root, "--m") -> {:ok, Map.fetch!(@legacy_thumb_sizes, :m)}
      width = responsive_width(root) -> {:ok, width}
      true -> {:error, :not_thumbnail}
    end
  end

  defp variant_url(url, width) do
    ext = Path.extname(url)
    root = Path.rootname(url, ext)
    "#{source_root(root)}--#{width}w#{ext}"
  end

  defp source_root(root) do
    cond do
      String.ends_with?(root, "--s") or String.ends_with?(root, "--m") ->
        String.slice(root, 0, byte_size(root) - 3)

      Regex.match?(~r/--\d+w$/, root) ->
        Regex.replace(~r/--\d+w$/, root, "")

      true ->
        root
    end
  end

  defp storage_image_url?(url) do
    path = URI.parse(url).path || url
    String.contains?(path, "/storage/v1/") and String.contains?(path, "/images/")
  end

  defp responsive_width(root) do
    case Regex.run(~r/--(\d+)w$/, root) do
      [_, width] ->
        width = String.to_integer(width)
        if width in @responsive_widths, do: width, else: nil

      _ ->
        nil
    end
  end

  defp resize_to_fit_atomic!(input_path, output_path, max_side) do
    tmp_path = temporary_output_path(output_path)

    try do
      ImageMagick.resize_to_fit!(input_path, tmp_path, max_side)
      File.rename!(tmp_path, output_path)
    after
      _ = File.rm(tmp_path)
    end
  end

  defp temporary_output_path(output_path) do
    ext = Path.extname(output_path)
    root = Path.rootname(output_path, ext)
    unique = System.unique_integer([:positive, :monotonic])
    "#{root}.tmp-#{unique}#{ext}"
  end

  defp gen_dest(user_id, filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
    normalized_filename = filename |> to_string() |> String.downcase()

    Path.join([user_id, "images", timestamp <> "_" <> normalized_filename])
  end
end
