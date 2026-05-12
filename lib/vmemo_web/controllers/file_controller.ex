defmodule VmemoWeb.FileController do
  use VmemoWeb, :controller

  @storage_root Path.expand("storage/v1")
  @allowed_mime_types %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".webp" => "image/webp"
  }

  def show(conn, %{"user_id" => user_id, "filename" => filename}) do
    with {:ok, safe_user_id} <- normalize_user_id(user_id),
         {:ok, safe_filename} <- normalize_filename(filename),
         {:ok, file_path} <- image_path(safe_user_id, safe_filename),
         {:ok, resolved_path} <- resolve_image_path(file_path) do
      send_storage_file(conn, resolved_path)
    else
      _ -> send_missing_image_not_found(conn)
    end
  end

  def show_avatar(conn, %{"user_id" => user_id, "filename" => filename}) do
    with {:ok, safe_user_id} <- normalize_user_id(user_id),
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

  defp send_storage_file(conn, file_path) do
    with {:ok, stat} <- File.stat(file_path),
         {:ok, file_bin} <- read_file_binary(file_path, stat.size),
         etag <- build_etag(file_path, stat),
         last_modified <- build_last_modified(stat),
         false <- fresh?(conn, etag, stat) do
      conn =
        conn
        |> put_resp_header("content-type", detect_safe_mime(file_path))
        |> put_resp_header("content-disposition", "inline")
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> put_resp_header("etag", etag)
        |> put_resp_header("last-modified", last_modified)

      send_resp(conn, 200, file_bin)
    else
      true ->
        conn
        |> put_resp_header("cache-control", "public, max-age=0, must-revalidate")
        |> put_resp_header("etag", build_etag!(file_path))
        |> put_resp_header("last-modified", build_last_modified!(file_path))
        |> send_resp(304, "")

      _ ->
        conn
        |> put_status(404)
        |> text("File not found")
    end
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
    # Avoid reading whole file on every request; use stable metadata-based ETag instead.
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

  defp fallback_original_image_path(file_path) do
    ext = Path.extname(file_path)
    root = Path.rootname(file_path, ext)

    fallback_root =
      if String.ends_with?(root, "--s") or String.ends_with?(root, "--m") do
        String.slice(root, 0, byte_size(root) - 3)
      end

    with fallback_root when is_binary(fallback_root) <- fallback_root,
         exact_candidate <- fallback_root <> ext,
         true <- File.exists?(exact_candidate) do
      {:ok, exact_candidate}
    else
      _ -> :error
    end
  end

  defp resolve_image_path(file_path) do
    if File.exists?(file_path) do
      {:ok, file_path}
    else
      fallback_original_image_path(file_path)
    end
  end

  defp normalize_filename(filename) when is_binary(filename) do
    normalized_filename = String.downcase(filename)

    if String.match?(normalized_filename, ~r/^[a-z0-9._-]+$/) do
      {:ok, normalized_filename}
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

  defp image_path(user_id, filename), do: safe_storage_path([user_id, "images", filename])

  defp avatar_path(user_id, filename), do: safe_storage_path([user_id, "avatars", filename])

  defp safe_storage_path(parts) do
    path = Path.join(["storage/v1" | parts]) |> Path.expand()

    if String.starts_with?(path, @storage_root <> "/") do
      {:ok, path}
    else
      {:error, :invalid_path}
    end
  end

  defp detect_safe_mime(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    Map.get(@allowed_mime_types, extension, "application/octet-stream")
  end

  defp read_file_binary(file_path, size)
       when is_binary(file_path) and is_integer(size) and size >= 0 do
    case :file.open(String.to_charlist(file_path), [:read, :binary]) do
      {:ok, io} ->
        try do
          case :file.read(io, size) do
            {:ok, data} -> {:ok, data}
            :eof -> {:ok, <<>>}
            {:error, _} = error -> error
          end
        after
          :file.close(io)
        end

      {:error, _} = error ->
        error
    end
  end
end
