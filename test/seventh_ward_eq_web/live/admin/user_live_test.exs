defmodule SeventhWardEqWeb.Admin.UserLiveTest do
  use SeventhWardEqWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SeventhWardEq.AccountsFixtures
  import SeventhWardEq.ContentFixtures

  describe "unauthenticated" do
    test "index redirects to log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, ~p"/admin/users")
    end

    test "new redirects to log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, ~p"/admin/users/new")
    end
  end

  describe "non-superadmin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{conn: log_in_user(conn, scope.user)}
    end

    test "index redirects to /admin", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin"}}} = live(conn, ~p"/admin/users")
    end

    test "new redirects to /admin", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin"}}} = live(conn, ~p"/admin/users/new")
    end
  end

  describe "index — superadmin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{role: "superadmin", auxiliary: nil})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "lists admin accounts", %{conn: conn} do
      admin_scope = admin_scope_fixture(%{auxiliary: "rs"})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ admin_scope.user.email
    end

    test "does not list superadmin accounts", %{conn: conn, scope: scope} do
      # Create a regular admin so the table is visible, then verify the
      # superadmin (current user) is absent from it.
      _admin_scope = admin_scope_fixture(%{auxiliary: "eq"})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-table")
      refute has_element?(view, "#users-table", scope.user.email)
    end

    test "deletes an admin account on confirm", %{conn: conn} do
      admin_scope = admin_scope_fixture(%{auxiliary: "eq"})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#user-#{admin_scope.user.id}")

      view
      |> element("#user-#{admin_scope.user.id} button", "Delete")
      |> render_click()

      refute has_element?(view, "#user-#{admin_scope.user.id}")
    end
  end

  describe "new admin form" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{role: "superadmin", auxiliary: nil})
      %{conn: log_in_user(conn, scope.user)}
    end

    test "renders form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users/new")
      assert has_element?(view, "#user-form")
    end

    test "shows validation error when fields are blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users/new")

      html =
        view
        |> form("#user-form", user: %{email: "", password: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "creates admin and redirects on valid submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users/new")

      view
      |> form("#user-form",
        user: %{
          email: unique_user_email(),
          auxiliary: "eq",
          password: valid_user_password(),
          password_confirmation: valid_user_password()
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")
    end
  end
end
