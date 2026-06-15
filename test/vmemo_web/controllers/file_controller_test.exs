defmodule VmemoWeb.FileControllerTest do
  use VmemoWeb.ConnCase, async: false

  import Vmemo.AccountFixtures

  @base_dir Path.join(["storage", "v1"])

  setup %{conn: conn} do
    user = user_fixture()
    other_user = user_fixture()
    conn = log_in_user(conn, user)
    previous_storage_accel_redirect = Application.get_env(:vmemo, :storage_accel_redirect?)
    Application.put_env(:vmemo, :storage_accel_redirect?, false)

    image_dir = Path.join([@base_dir, user.id, "images"])
    File.mkdir_p!(image_dir)

    on_exit(fn ->
      restore_storage_accel_redirect(previous_storage_accel_redirect)
      File.rm_rf!(Path.join([@base_dir, user.id]))
      File.rm_rf!(Path.join([@base_dir, other_user.id]))
    end)

    {:ok, conn: conn, user: user, other_user: other_user, image_dir: image_dir}
  end

  test "generates medium thumbnail when thumbnail is missing", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "sample.png")
    thumbnail = Path.join(image_dir, "sample--m.png")
    File.cp!(fixture, original)
    refute File.exists?(thumbnail)

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/sample--m.png")

    assert response(conn, 200) == File.read!(thumbnail)
    assert File.exists?(thumbnail)
    assert File.stat!(thumbnail).size < File.stat!(original).size

    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert get_resp_header(conn, "content-disposition") == ["inline"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=0, must-revalidate"]
    assert [etag] = get_resp_header(conn, "etag")
    assert String.starts_with?(etag, "\"vmemo-")
  end

  test "generates and accelerates missing thumbnail instead of serving original", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "large.png")
    thumbnail = Path.join(image_dir, "large--s.png")
    File.cp!(fixture, original)
    refute File.exists?(thumbnail)

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/large--s.png")

    assert response(conn, 200) == File.read!(thumbnail)
    assert File.exists?(thumbnail)
    assert File.stat!(thumbnail).size < File.stat!(original).size

    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "generates width-based responsive image variant when missing", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "responsive.png")
    variant = Path.join(image_dir, "responsive--640w.webp")
    File.cp!(fixture, original)
    refute File.exists?(variant)

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/responsive--640w.webp")

    assert response(conn, 200) == File.read!(variant)
    assert File.exists?(variant)
    assert File.stat!(variant).size < File.stat!(original).size

    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/webp"]
  end

  test "rejects unsupported responsive image width variants", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "responsive.png")
    variant = Path.join(image_dir, "responsive--777w.png")
    File.cp!(fixture, original)

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/responsive--777w.png")

    assert response(conn, 404) == "File not found"
    refute File.exists?(variant)
  end

  test "falls back to another extension when exact original does not exist", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    png = Path.join(image_dir, "sample.png")
    webp_thumbnail = Path.join(image_dir, "sample--m.webp")
    File.cp!(fixture, png)
    refute File.exists?(webp_thumbnail)

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/sample--m.webp")

    assert response(conn, 200) == File.read!(webp_thumbnail)
    assert File.exists?(webp_thumbnail)

    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/webp"]
  end

  test "accelerates tiff images with image/tiff content type", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    tiff = Path.join(image_dir, "sample.tiff")
    File.write!(tiff, "tiff-data")

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/sample.tiff")

    assert response(conn, 200) == "tiff-data"
    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/tiff"]
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

  test "returns 404 with no-store when both thumbnail and original are missing", %{
    conn: conn,
    user: user
  } do
    conn = get(conn, ~p"/storage/v1/#{user.id}/images/not-found--s.png")

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

  test "accelerates avatar when file exists", %{conn: conn, user: user} do
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

  test "serves file bytes by default for direct Phoenix storage requests", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    original = Path.join(image_dir, "direct.png")
    File.write!(original, "direct-data")

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/direct.png")

    assert response(conn, 200) == "direct-data"
    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "uses x-accel-redirect when storage acceleration is enabled", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    Application.put_env(:vmemo, :storage_accel_redirect?, true)

    original = Path.join(image_dir, "accelerated.png")
    File.write!(original, "accelerated-data")

    conn = get(conn, ~p"/storage/v1/#{user.id}/images/accelerated.png")

    assert response(conn, 200) == ""

    assert get_resp_header(conn, "x-accel-redirect") == [
             "/storage/v1/_internal/#{user.id}/images/accelerated.png"
           ]

    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert get_resp_header(conn, "content-disposition") == ["inline"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=0, must-revalidate"]
  end

  test "uses x-accel-redirect when request comes through storage proxy", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    original = Path.join(image_dir, "proxied.png")
    File.write!(original, "proxied-data")

    conn =
      conn
      |> put_req_header("x-vmemo-storage-accel", "true")
      |> get(~p"/storage/v1/#{user.id}/images/proxied.png")

    assert response(conn, 200) == ""

    assert get_resp_header(conn, "x-accel-redirect") == [
             "/storage/v1/_internal/#{user.id}/images/proxied.png"
           ]

    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  defp restore_storage_accel_redirect(nil) do
    Application.delete_env(:vmemo, :storage_accel_redirect?)
  end

  defp restore_storage_accel_redirect(value) do
    Application.put_env(:vmemo, :storage_accel_redirect?, value)
  end
end
