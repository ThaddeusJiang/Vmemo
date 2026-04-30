defmodule VmemoWeb.FileController do
  use VmemoWeb, :controller

  alias Vmemo.Account.UserProfileStorage

  def show(conn, %{"user_id" => user_id, "filename" => filename}) do
    file_path = Path.join(["storage/v1", user_id, "images", filename])

    if File.exists?(file_path) do
      send_storage_file(conn, file_path)
    else
      conn
      |> put_status(404)
      |> text("File not found")
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
         etag <- build_etag(file_path),
         last_modified <- build_last_modified(stat),
         false <- fresh?(conn, etag, stat) do
      conn
      |> put_resp_content_type(MIME.from_path(file_path))
      |> put_resp_header("cache-control", "public, max-age=0, must-revalidate")
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
    build_etag(file_path)
  end

  defp build_last_modified!(file_path) do
    {:ok, stat} = File.stat(file_path)
    build_last_modified(stat)
  end

  defp build_etag(file_path) do
    hash =
      file_path
      |> File.read!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ~s("#{hash}")
  end

  defp build_last_modified(stat) do
    stat.mtime
    |> :httpd_util.rfc1123_date()
    |> to_string()
  end
end
