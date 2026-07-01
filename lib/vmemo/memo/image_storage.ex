defmodule Vmemo.Memo.ImageStorage do
  @moduledoc false
  alias SmallSdk.FileSystem
  alias SmallSdk.ImageMagick

  @image_extensions [".png", ".jpg", ".jpeg", ".gif", ".webp", ".tif", ".tiff"]
  @variant_sizes %{thumb: 400, detail: 800}
  @variant_extension ".webp"

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

  def generate_variants!(storage_path) when is_binary(storage_path) do
    Enum.each(@variant_sizes, fn {variant, max_side} ->
      storage_path
      |> variant_path(variant)
      |> then(&resize_to_fit_atomic!(storage_path, &1, max_side))
    end)

    :ok
  end

  def thumbs!(storage_path) when is_binary(storage_path) do
    generate_variants!(storage_path)
  end

  def generate_variants_for_image_file!(storage_path) when is_binary(storage_path) do
    if storage_image_file?(storage_path) and original_image_file?(storage_path) do
      generate_variants!(storage_path)
    else
      :ok
    end
  end

  def variant_path(storage_path, :original) when is_binary(storage_path), do: storage_path

  def variant_path(storage_path, variant)
      when is_binary(storage_path) and is_map_key(@variant_sizes, variant) do
    ext = Path.extname(storage_path)
    root = Path.rootname(storage_path, ext)
    "#{root}.#{variant}#{@variant_extension}"
  end

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

    String.ends_with?(root, ".thumb") or String.ends_with?(root, ".detail") or
      String.ends_with?(root, "--s") or String.ends_with?(root, "--m") or
      Regex.match?(~r/--\d+w$/, root)
  end

  defp storage_image_file?(path) do
    path
    |> Path.expand()
    |> String.contains?("/images/")
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
