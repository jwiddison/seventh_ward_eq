defmodule SeventhWardEqWeb.Admin.PostLiveTest do
  use SeventhWardEqWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SeventhWardEq.ContentFixtures

  describe "unauthenticated" do
    test "index redirects to log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, ~p"/admin/posts")
    end

    test "new redirects to log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, ~p"/admin/posts/new")
    end
  end

  describe "index — admin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "lists posts for the admin's auxiliary", %{conn: conn, scope: scope} do
      post = post_fixture(scope)
      other_scope = admin_scope_fixture(%{auxiliary: "rs"})
      _other_post = post_fixture(other_scope, title: "Other Aux Post")

      {:ok, _view, html} = live(conn, ~p"/admin/posts")

      assert html =~ post.title
      refute html =~ "Other Aux Post"
    end

    test "shows New Post button for regular admin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/posts")
      assert html =~ "New Post"
    end

    test "deletes a post on confirm", %{conn: conn, scope: scope} do
      post = post_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/admin/posts")

      assert has_element?(view, "#post-#{post.id}")

      view
      |> element("#post-#{post.id} button", "Delete")
      |> render_click()

      refute has_element?(view, "#post-#{post.id}")
    end
  end

  describe "index — superadmin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{role: "superadmin", auxiliary: nil})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "lists posts from all auxiliaries", %{conn: conn} do
      eq_scope = admin_scope_fixture(%{auxiliary: "eq"})
      rs_scope = admin_scope_fixture(%{auxiliary: "rs"})
      eq_post = post_fixture(eq_scope, title: "EQ Post")
      rs_post = post_fixture(rs_scope, title: "RS Post")

      {:ok, _view, html} = live(conn, ~p"/admin/posts")

      assert html =~ eq_post.title
      assert html =~ rs_post.title
    end

    test "does not show New Post button for superadmin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/posts")
      refute html =~ "New Post"
    end
  end

  describe "new post form" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "renders form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts/new")
      assert has_element?(view, "#post-form")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

      html =
        view
        |> form("#post-form", post: %{title: "", body: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "creates post and redirects on valid submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

      view
      |> form("#post-form", post: %{title: "Brand New Post", body: "<p>Hello</p>"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/posts")
    end
  end

  describe "edit post form" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      post = post_fixture(scope)
      %{conn: log_in_user(conn, scope.user), scope: scope, post: post}
    end

    test "renders form with existing values", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post.id}/edit")
      assert has_element?(view, "#post-form")
      assert render(view) =~ post.title
    end

    test "updates post and redirects on valid submit", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post.id}/edit")

      view
      |> form("#post-form", post: %{title: "Updated Title"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/posts")
    end
  end
end
