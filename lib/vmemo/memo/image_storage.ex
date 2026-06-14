defmodule Vmemo.Memo.ImageStorage do
  @moduledoc false
  alias SmallSdk.FileSystem
  alias SmallSdk.ImageMagick
  alias Vmemo.Storage

  @thumb_sizes %{s: 320, m: 1280}

  def cp_file(src, user_id, filename) do
    dest = FileSystem.cp!(src, gen_dest(user_id, filename))
    {:ok, dest}
  end

  def thumbs!(storage_path) when is_binary(storage_path) do
    ext = Path.extname(storage_path)
    root = Path.rootname(storage_path, ext)

    Enum.each(@thumb_sizes, fn {size, max_side} ->
      thumb_path = "#{root}--#{size}#{ext}"
      resize_to_fit_atomic!(storage_path, thumb_path, max_side)
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

  def thumbnail_url(url, _size), do: url

  def storage_path_from_url(url, user_id) when is_binary(url) and not is_nil(user_id) do
    parsed = URI.parse(url)
    raw_path = parsed.path || url

    primary = storage_path_from_raw_url_path(raw_path)
    fallback = fallback_image_path(raw_path, user_id)

    cond do
      existing_image_path?(primary) ->
        {:ok, primary}

      File.exists?(fallback) ->
        {:ok, fallback}

      true ->
        {:error, :file_not_found}
    end
  end

  def storage_path_from_url(_, _), do: {:error, :invalid_url}

  defp storage_path_from_raw_url_path(raw_path) do
    case Storage.path_from_url(raw_path) do
      {:ok, path} -> path
      {:error, _reason} -> nil
    end
  end

  defp fallback_image_path(raw_path, user_id) do
    raw_path
    |> Path.basename()
    |> then(&Storage.path(["v1", to_string(user_id), "images", &1]))
  end

  defp existing_image_path?(path) when is_binary(path) do
    String.contains?(path, "/images/") and File.exists?(path)
  end

  defp existing_image_path?(_path), do: false

  defp thumbnail_max_side(path) do
    ext = Path.extname(path)
    root = Path.rootname(path, ext)

    cond do
      String.ends_with?(root, "--s") -> {:ok, Map.fetch!(@thumb_sizes, :s)}
      String.ends_with?(root, "--m") -> {:ok, Map.fetch!(@thumb_sizes, :m)}
      true -> {:error, :not_thumbnail}
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
