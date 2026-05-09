defmodule VmemoWeb.FileController do
  use VmemoWeb, :controller

  alias Vmemo.Account.UserProfileStorage

  def show(conn, %{"user_id" => user_id, "filename" => filename}) do
    file_path = Path.join(["storage/v1", user_id, "images", filename])

    if File.exists?(file_path) do
      send_storage_file(conn, file_path)
    else
      case fallback_original_image_path(file_path) do
        {:ok, fallback_path} -> send_storage_file(conn, fallback_path)
        :error -> send_missing_image_not_found(conn)
      end
    end
  end

  def show_avatar(conn, %{"user_id" => user_id, "filename" => filename}) do
    file_path = UserProfileStorage.avatar_path(user_id, filename)

    if File.exists?(file_path) do
      send_storage_file(conn, file_path)
    else
      conn
      |> put_status(404)
      |> text("File not found")
    end
  end

  defp send_storage_file(conn, file_path) do
    with {:ok, stat} <- File.stat(file_path),
         etag <- build_etag(file_path, stat),
         last_modified <- build_last_modified(stat),
         false <- fresh?(conn, etag, stat) do
      conn
      |> put_resp_content_type(MIME.from_path(file_path), nil)
      |> put_resp_header("content-disposition", "inline")
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> put_resp_header("etag", etag)
      |> put_resp_header("last-modified", last_modified)
      |> send_file(200, file_path)
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
      cond do
        String.ends_with?(root, "--s") -> String.trim_trailing(root, "--s")
        String.ends_with?(root, "--m") -> String.trim_trailing(root, "--m")
        true -> nil
      end

    case fallback_root do
      nil ->
        :error

      _ ->
        exact_candidate = fallback_root <> ext

        cond do
          File.exists?(exact_candidate) ->
            {:ok, exact_candidate}

          true ->
            find_fallback_candidate_by_extension(fallback_root, ext)
        end
    end
  end

  defp find_fallback_candidate_by_extension(fallback_root, requested_ext) do
    requested_ext = String.downcase(requested_ext || "")

    ext_priority =
      [requested_ext, ".png", ".jpg", ".jpeg", ".webp", ".gif"]
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    candidates_by_ext =
      Path.wildcard(fallback_root <> ".*")
      |> Enum.group_by(&(Path.extname(&1) |> String.downcase()))

    match =
      Enum.find_value(ext_priority, fn ext ->
        case Map.get(candidates_by_ext, ext, []) do
          [path | _] -> path
          [] -> nil
        end
      end)

    if is_binary(match), do: {:ok, match}, else: :error
  end
end
