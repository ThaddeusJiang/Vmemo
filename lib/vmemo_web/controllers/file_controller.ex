defmodule VmemoWeb.FileController do
  use VmemoWeb, :controller

  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Storage

  @cache_control "public, max-age=0, must-revalidate"
  @allowed_mime_types %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".webp" => "image/webp",
    ".tif" => "image/tiff",
    ".tiff" => "image/tiff"
  }

  def show(conn, %{"user_id" => user_id, "filename" => filename}) do
    with {:ok, safe_user_id} <- normalize_user_id(user_id),
         :ok <- authorize_storage_user(conn, safe_user_id),
         {:ok, safe_filename} <- normalize_filename(filename),
         {:ok, file_path} <- image_path(safe_user_id, safe_filename),
         true <- File.exists?(file_path) do
      send_storage_file(conn, file_path)
    else
      _ -> send_missing_image_not_found(conn)
    end
  end

  def show_avatar(conn, %{"user_id" => user_id, "filename" => filename}) do
    with {:ok, safe_user_id} <- normalize_user_id(user_id),
         :ok <- authorize_storage_user(conn, safe_user_id),
         {:ok, safe_filename} <- normalize_filename(filename),
         {:ok, file_path} <- avatar_path(safe_user_id, safe_filename) do
      if File.exists?(file_path) do
        send_storage_file(conn, file_path)
      else
        send_missing_image_not_found(conn)
      end
    else
      _ -> send_missing_image_not_found(conn)
    end
  end

  def show_image_variant(conn, %{"id" => id, "variant" => variant}) do
    with {:ok, variant} <- normalize_image_variant(variant),
         %{id: user_id} = current_user <- conn.assigns[:current_user],
         {:ok, image} <- Image.get(id, actor: current_user),
         ^user_id <- image.user_id,
         {:ok, original_path} <- ImageStorage.storage_path_from_url(image.url, user_id),
         file_path <- ImageStorage.variant_path(original_path, variant),
         true <- File.exists?(file_path) do
      send_storage_file(conn, file_path)
    else
      _ -> send_missing_image_not_found(conn)
    end
  end

  defp send_storage_file(conn, file_path) do
    with {:ok, stat} <- File.stat(file_path),
         etag <- build_etag(file_path, stat),
         last_modified <- build_last_modified(stat),
         false <- fresh?(conn, etag, stat) do
      conn
      |> put_storage_headers(file_path, etag, last_modified)
      |> send_storage_body(file_path)
    else
      true ->
        conn
        |> put_resp_header("cache-control", @cache_control)
        |> put_resp_header("etag", build_etag!(file_path))
        |> put_resp_header("last-modified", build_last_modified!(file_path))
        |> send_resp(304, "")

      _ ->
        conn
        |> put_status(404)
        |> text("File not found")
    end
  end

  defp authorize_storage_user(conn, user_id) do
    case conn.assigns[:current_user] do
      %{id: ^user_id} -> :ok
      %{id: current_user_id} when is_binary(current_user_id) -> :error
      _ -> :error
    end
  end

  defp put_storage_headers(conn, file_path, etag, last_modified) do
    conn
    |> put_resp_header("content-type", detect_safe_mime(file_path))
    |> put_resp_header("content-disposition", "inline")
    |> put_resp_header("cache-control", @cache_control)
    |> put_resp_header("etag", etag)
    |> put_resp_header("last-modified", last_modified)
  end

  defp send_storage_body(conn, file_path) do
    send_file(conn, 200, file_path)
  end

  defp fresh?(conn, etag, stat) do
    if_none_match_present? = get_req_header(conn, "if-none-match") != []

    if if_none_match_present? do
      etag_fresh?(conn, etag)
    else
      modified_since_fresh?(conn, stat)
    end
  end

  defp etag_fresh?(conn, etag) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.any?(fn value ->
      value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.any?(&(&1 == etag or &1 == "*"))
    end)
  end

  defp modified_since_fresh?(conn, stat) do
    conn
    |> get_req_header("if-modified-since")
    |> Enum.any?(fn value ->
      case :httpd_util.convert_request_date(String.to_charlist(value)) do
        :bad_date ->
          false

        request_datetime ->
          :calendar.datetime_to_gregorian_seconds(request_datetime) >=
            :calendar.datetime_to_gregorian_seconds(stat.mtime)
      end
    end)
  end

  defp build_etag!(file_path) do
    {:ok, stat} = File.stat(file_path)
    build_etag(file_path, stat)
  end

  defp build_last_modified!(file_path) do
    {:ok, stat} = File.stat(file_path)
    build_last_modified(stat)
  end

  defp build_etag(_file_path, stat) do
    mtime = :calendar.datetime_to_gregorian_seconds(stat.mtime)
    size = stat.size
    inode = Map.get(stat, :inode, 0)
    ~s("vmemo-#{inode}-#{size}-#{mtime}")
  end

  defp build_last_modified(stat) do
    stat.mtime
    |> :httpd_util.rfc1123_date()
    |> to_string()
  end

  defp send_missing_image_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(404, "File not found")
  end

  defp normalize_filename(filename) when is_binary(filename) do
    if String.match?(filename, ~r/^[A-Za-z0-9._-]+$/) do
      {:ok, filename}
    else
      {:error, :invalid_filename}
    end
  end

  defp normalize_filename(_), do: {:error, :invalid_filename}

  defp normalize_user_id(user_id) when is_binary(user_id) do
    if String.match?(user_id, ~r/^[a-z0-9-]+$/) do
      {:ok, user_id}
    else
      {:error, :invalid_user_id}
    end
  end

  defp normalize_user_id(_), do: {:error, :invalid_user_id}

  defp normalize_image_variant("thumb"), do: {:ok, :thumb}
  defp normalize_image_variant("detail"), do: {:ok, :detail}
  defp normalize_image_variant("original"), do: {:ok, :original}
  defp normalize_image_variant(_), do: {:error, :invalid_variant}

  defp image_path(user_id, filename), do: safe_storage_path([user_id, "images", filename])

  defp avatar_path(user_id, filename), do: safe_storage_path([user_id, "avatars", filename])

  defp safe_storage_path(parts) do
    path = Storage.path(["v1" | parts])
    storage_root = Storage.v1_path()

    if String.starts_with?(path, storage_root <> "/") do
      {:ok, path}
    else
      {:error, :invalid_path}
    end
  end

  defp detect_safe_mime(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    Map.get(@allowed_mime_types, extension, "application/octet-stream")
  end
end
