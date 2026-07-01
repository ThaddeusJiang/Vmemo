defmodule VmemoWeb.FileControllerTest do
  use VmemoWeb.ConnCase, async: false

  import Vmemo.AccountFixtures

  alias Vmemo.Storage

  @base_dir Storage.v1_path()

  setup %{conn: conn} do
    user = user_fixture()
    other_user = user_fixture()
    conn = log_in_user(conn, user)

    image_dir = Path.join([@base_dir, user.id, "images"])
    File.mkdir_p!(image_dir)

    on_exit(fn ->
      File.rm_rf!(Path.join([@base_dir, user.id]))
      File.rm_rf!(Path.join([@base_dir, other_user.id]))
    end)

    {:ok, conn: conn, user: user, other_user: other_user, image_dir: image_dir}
  end

  test "serves stored image bytes directly", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    image = Path.join(image_dir, "sample.png")
    File.write!(image, "png-data")

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/sample.png")

    assert response(conn, 200) == "png-data"
    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert get_resp_header(conn, "content-disposition") == ["inline"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=0, must-revalidate"]
    assert [etag] = get_resp_header(conn, "etag")
    assert String.starts_with?(etag, "\"vmemo-")
  end

  test "does not generate a missing storage image variant", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "sample.png")
    variant = Path.join(image_dir, "sample.thumb.webp")
    File.cp!(fixture, original)
    refute File.exists?(variant)

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/sample.thumb.webp")

    assert response(conn, 404) == "File not found"
    refute File.exists?(variant)
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "preserves uppercase extension when serving stored image files", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    image = Path.join(image_dir, "Camera.JPG")
    File.write!(image, "jpg-data")

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/Camera.JPG")

    assert response(conn, 200) == "jpg-data"
    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/jpeg"]
  end

  test "returns 404 with no-store when image is missing", %{conn: conn, user: user} do
    conn = get(conn, ~p"/storage/v1/#{user.id}/images/not-found.png")

    assert response(conn, 404) == "File not found"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end

  test "returns 304 when if-none-match matches etag", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    original = Path.join(image_dir, "etag.png")
    File.write!(original, "etag-data")

    first = get(conn, ~p"/storage/v1/#{user.id}/images/etag.png")
    assert response(first, 200) == "etag-data"
    [etag] = get_resp_header(first, "etag")

    second =
      conn
      |> put_req_header("if-none-match", etag)
      |> get(~p"/storage/v1/#{user.id}/images/etag.png")

    assert response(second, 304) == ""
    assert get_resp_header(second, "cache-control") == ["public, max-age=0, must-revalidate"]
  end

  test "returns 404 for invalid filename pattern", %{conn: conn, user: user} do
    conn = get(conn, "/storage/v1/#{user.id}/images/evil file.png")
    assert response(conn, 404) == "File not found"
  end

  test "serves avatar bytes directly", %{conn: conn, user: user} do
    avatar_dir = Path.join([@base_dir, user.id, "avatars"])
    File.mkdir_p!(avatar_dir)
    avatar = Path.join(avatar_dir, "me.jpg")
    File.write!(avatar, "jpg-data")

    conn = get(conn, ~p"/storage/v1/#{user.id}/avatars/me.jpg")

    assert response(conn, 200) == "jpg-data"
    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/jpeg"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=0, must-revalidate"]
  end

  test "does not serve image files to anonymous users", %{
    user: user,
    image_dir: image_dir
  } do
    original = Path.join(image_dir, "private.png")
    File.write!(original, "private-data")

    conn =
      Phoenix.ConnTest.build_conn()
      |> get(~p"/storage/v1/#{user.id}/images/private.png")

    assert response(conn, 404) == "File not found"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "does not serve another user's image files", %{
    other_user: other_user,
    user: user,
    image_dir: image_dir
  } do
    original = Path.join(image_dir, "private.png")
    File.write!(original, "private-data")

    conn =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(other_user)
      |> get(~p"/storage/v1/#{user.id}/images/private.png")

    assert response(conn, 404) == "File not found"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end
end
