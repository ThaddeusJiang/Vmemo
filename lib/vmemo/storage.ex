defmodule Vmemo.Storage do
  @moduledoc false

  @url_v1_prefix "/storage/v1"
  @relative_v1_prefix "storage/v1"

  def img(url, size) when size in [:s, :m] and is_binary(url) do
    ext = Path.extname(url)
    root = Path.rootname(url, ext)
    "#{root}--#{size}#{ext}"
  end

  def img(url, _size), do: url

  def root_path do
    :vmemo
    |> Application.get_env(:storage_root, default_root_path())
    |> normalize_root_path()
  end

  def v1_path, do: path("v1")

  def path(parts) when is_list(parts) do
    parts
    |> Path.join()
    |> path()
  end

  def path(part) when is_binary(part) do
    root = root_path()
    path = Path.expand(part, root)

    if path == root or String.starts_with?(path, root <> "/") do
      path
    else
      raise ArgumentError, "storage path escapes configured storage root"
    end
  end

  def path_from_url(url) when is_binary(url) do
    with {:ok, relative_path} <- relative_v1_path_from_url(url) do
      {:ok, path(relative_path)}
    end
  end

  def path_from_url(_url), do: {:error, :invalid_url}

  def url_path(parts) when is_list(parts) do
    parts
    |> Path.join()
    |> url_path()
  end

  def url_path("v1/" <> relative_path), do: Path.join(@url_v1_prefix, relative_path)
  def url_path("v1"), do: @url_v1_prefix

  def url_path(relative_path) when is_binary(relative_path) do
    Path.join(@url_v1_prefix, relative_path)
  end

  def url_path_from_path!(path) when is_binary(path) do
    path = Path.expand(path)
    v1_path = v1_path()

    cond do
      path == v1_path ->
        @url_v1_prefix

      String.starts_with?(path, v1_path <> "/") ->
        relative_path = Path.relative_to(path, v1_path)
        Path.join(@url_v1_prefix, relative_path)

      true ->
        raise ArgumentError, "storage path is outside configured v1 storage root"
    end
  end

  defp relative_v1_path_from_url(url) do
    path =
      case URI.parse(url) do
        %URI{path: nil} -> url
        %URI{path: parsed_path} -> parsed_path
      end

    cond do
      String.starts_with?(path, @url_v1_prefix <> "/") ->
        {:ok, "v1/" <> String.replace_prefix(path, @url_v1_prefix <> "/", "")}

      path == @url_v1_prefix ->
        {:ok, "v1"}

      String.starts_with?(path, @relative_v1_prefix <> "/") ->
        {:ok, "v1/" <> String.replace_prefix(path, @relative_v1_prefix <> "/", "")}

      path == @relative_v1_prefix ->
        {:ok, "v1"}

      true ->
        {:error, :invalid_url}
    end
  end

  defp normalize_root_path(path) when is_binary(path) do
    case String.trim(path) do
      "" -> default_root_path()
      path -> Path.expand(path)
    end
  end

  defp normalize_root_path(_path), do: default_root_path()

  defp default_root_path, do: Path.expand("data/storage")
end
