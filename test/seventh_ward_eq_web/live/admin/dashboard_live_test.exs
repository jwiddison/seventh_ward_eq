defmodule SeventhWardEqWeb.Admin.DashboardLiveTest do
  use SeventhWardEqWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SeventhWardEq.ContentFixtures
  import SeventhWardEq.EventsFixtures, only: [event_fixture: 1]

  describe "unauthenticated" do
    test "redirects to log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, ~p"/admin")
    end
  end

  describe "admin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "renders dashboard with post and event counts", %{conn: conn, scope: scope} do
      _post = post_fixture(scope)
      _event = event_fixture(scope)

      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Dashboard"
      assert html =~ "Posts"
      assert html =~ "Events"
    end

    test "shows the admin's auxiliary name in the sidebar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Elder&#39;s Quorum"
    end

    test "does not show Users nav link for regular admin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      refute html =~ ~p"/admin/users"
    end
  end

  describe "superadmin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{role: "superadmin", auxiliary: nil})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "renders dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Dashboard"
      assert html =~ "All Auxiliaries"
    end

    test "shows Users nav link for superadmin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ ~p"/admin/users"
    end
  end
end
