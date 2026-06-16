defmodule Vmemo.Memo.ImageStorage do
  @moduledoc false
  alias SmallSdk.FileSystem
  alias SmallSdk.ImageMagick

  @image_extensions [".png", ".jpg", ".jpeg", ".gif", ".webp", ".tif", ".tiff"]
  @storage_root Path.expand("storage/v1")
  @cache_version_param "v"
  @legacy_thumb_sizes %{s: 320, m: 1280}
  @responsive_widths [160, 320, 640, 1280, 1920]
  @responsive_widths_by_usage %{
    thumb: [160, 320],
    grid: [160, 320, 640],
    detail: [320, 640, 1280],
    full: [640, 1280, 1920]
  }
  @responsive_extension ".webp"
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

  def warm_variants!(storage_root \\ Path.join(["storage", "v1"]), opts \\ []) do
    storage_root
    |> storage_image_paths()
    |> maybe_take_limit(Keyword.get(opts, :limit))
    |> Enum.reduce(%{processed: 0, failed: 0}, fn path, stats ->
      try do
        thumbs!(path)
        Map.update!(stats, :processed, &(&1 + 1))
      rescue
        _ -> Map.update!(stats, :failed, &(&1 + 1))
      end
    end)
  end

  def thumbs!(storage_path) when is_binary(storage_path) do
    ext = Path.extname(storage_path)
    root = Path.rootname(storage_path, ext)

    Enum.each(@legacy_thumb_sizes, fn {size, max_side} ->
      thumb_path = "#{root}--#{size}#{ext}"
      resize_to_fit_atomic!(storage_path, thumb_path, max_side)
    end)

    Enum.each(@responsive_widths, fn width ->
      variant_path = "#{root}--#{width}w#{@responsive_extension}"
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
    path = url_path(url)
    ext = Path.extname(path)
    root = Path.rootname(path, ext)

    "#{root}--#{size}#{ext}"
    |> put_cache_version(cache_version(url))
  end

  def thumbnail_url(url, width) when width in @responsive_widths and is_binary(url) do
    if storage_image_url?(url) do
      url
      |> variant_url(width)
      |> put_cache_version(cache_version(url))
    else
      url
    end
  end

  def thumbnail_url(url, _size), do: url

  def srcset(url) when is_binary(url) do
    build_srcset(url, @responsive_widths)
  end

  def srcset(_), do: nil

  def srcset(url, usage) when is_binary(url) do
    widths = Map.get(@responsive_widths_by_usage, usage, @responsive_widths)
    build_srcset(url, widths)
  end

  def srcset(_, _), do: nil

  defp build_srcset(url, widths) do
    if storage_image_url?(url) do
      version = cache_version(url)

      widths
      |> Enum.map_join(", ", fn width ->
        candidate =
          url
          |> variant_url(width)
          |> put_cache_version(version)

        "#{candidate} #{width}w"
      end)
    end
  end

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
    path = url_path(url)
    root = Path.rootname(path, Path.extname(path))
    "#{source_root(root)}--#{width}w#{@responsive_extension}"
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
    path = url_path(url)
    String.contains?(path, "/storage/v1/") and String.contains?(path, "/images/")
  end

  defp cache_version(url) do
    with path when is_binary(path) <- source_storage_path(url),
         {:ok, stat} <- File.stat(path) do
      mtime = :calendar.datetime_to_gregorian_seconds(stat.mtime)
      inode = Map.get(stat, :inode, 0)
      "#{inode}-#{stat.size}-#{mtime}"
    else
      _ -> nil
    end
  end

  defp source_storage_path(url) do
    path =
      url
      |> url_path()
      |> String.trim_leading("/")
      |> Path.expand()

    if String.starts_with?(path, @storage_root <> "/") do
      path
      |> source_path_candidates()
      |> Enum.find(&File.exists?/1)
    end
  end

  defp source_path_candidates(path) do
    ext = Path.extname(path)
    root = Path.rootname(path, ext)
    source_root = source_root(root)

    if source_root == root do
      [path]
    else
      ([source_root <> ext] ++ Enum.map(@image_extensions, &(source_root <> &1)))
      |> Enum.uniq()
    end
  end

  defp put_cache_version(url, nil), do: url

  defp put_cache_version(url, version) do
    uri = URI.parse(url)

    query =
      uri.query
      |> decode_query()
      |> Map.put(@cache_version_param, version)
      |> URI.encode_query()

    %{uri | query: query}
    |> URI.to_string()
  end

  defp decode_query(nil), do: %{}
  defp decode_query(query), do: URI.decode_query(query)

  defp url_path(url) do
    URI.parse(url).path || url
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

  defp storage_image_paths(storage_root) do
    [storage_root, "*", "images", "*"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.filter(&original_image_file?/1)
  end

  defp maybe_take_limit(paths, limit) when is_integer(limit) and limit > 0 do
    Enum.take(paths, limit)
  end

  defp maybe_take_limit(paths, _), do: paths

  defp original_image_file?(path) do
    File.regular?(path) and supported_image_extension?(path) and not generated_variant?(path)
  end

  defp supported_image_extension?(path) do
    path
    |> Path.extname()
    |> String.downcase()
    |> then(&(&1 in @image_extensions))
  end

  defp generated_variant?(path) do
    root = Path.rootname(path, Path.extname(path))

    String.ends_with?(root, "--s") or String.ends_with?(root, "--m") or
      Regex.match?(~r/--\d+w$/, root)
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
