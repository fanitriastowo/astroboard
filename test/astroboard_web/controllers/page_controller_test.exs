defmodule AstroboardWeb.PageControllerTest do
  use AstroboardWeb.ConnCase

  test "GET / redirects guests to the log in page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  describe "when authenticated" do
    setup :register_and_log_in_user

    test "GET / redirects to the boards dashboard", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/boards"
    end
  end
end
