defmodule VmemoWeb.PageControllerTest do
  use VmemoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Vmemo"
  end

  test "browser content security policy allows application fonts", %{conn: conn} do
    conn = get(conn, ~p"/")

    [content_security_policy] = get_resp_header(conn, "content-security-policy")

    assert content_security_policy =~
             "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com"

    assert content_security_policy =~ "font-src 'self' https://fonts.gstatic.com"
  end
end
