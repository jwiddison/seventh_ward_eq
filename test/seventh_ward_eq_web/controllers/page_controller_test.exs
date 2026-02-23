defmodule SeventhWardEqWeb.PageControllerTest do
  use SeventhWardEqWeb.ConnCase

  test "GET / redirects to /eq", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/eq"
  end
end
