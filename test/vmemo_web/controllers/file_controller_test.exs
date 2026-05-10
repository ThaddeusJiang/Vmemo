defmodule VmemoWeb.FileControllerTest do
  use VmemoWeb.ConnCase, async: true

  @base_dir Path.join(["storage", "v1"])

  setup do
    user_id = "test-user-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@base_dir, user_id, "images"])
    File.mkdir_p!(image_dir)

    on_exit(fn ->
      File.rm_rf!(Path.join([@base_dir, user_id]))
    end)

    {:ok, user_id: user_id, image_dir: image_dir}
  end

  test "returns original image when thumbnail is missing", %{
    conn: conn,
    user_id: user_id,
    image_dir: image_dir
  } do
    original = Path.join(image_dir, "sample.png")
    File.write!(original, "png-data")

    conn = get(conn, ~p"/storage/v1/#{user_id}/images/sample--m.png")

    assert response(conn, 200) == "png-data"
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert get_resp_header(conn, "content-disposition") == ["inline"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    assert [etag] = get_resp_header(conn, "etag")
    assert String.starts_with?(etag, "\"vmemo-")
  end

  test "falls back to another extension when exact original does not exist", %{
    conn: conn,
    user_id: user_id,
    image_dir: image_dir
  } do
    png = Path.join(image_dir, "sample.png")
    File.write!(png, "png-fallback")

    conn = get(conn, ~p"/storage/v1/#{user_id}/images/sample--m.webp")

    assert response(conn, 200) == "png-fallback"
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "returns 404 with no-store when both thumbnail and original are missing", %{
    conn: conn,
    user_id: user_id
  } do
    conn = get(conn, ~p"/storage/v1/#{user_id}/images/not-found--s.png")

    assert response(conn, 404) == "File not found"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
