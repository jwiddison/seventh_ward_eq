defmodule SeventhWardEqWeb.Admin.EventLiveTest do
  use SeventhWardEqWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SeventhWardEq.EventsFixtures

  describe "unauthenticated" do
    test "index redirects to log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, ~p"/admin/events")
    end
  end

  describe "index — admin" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "lists events for the admin's auxiliary", %{conn: conn, scope: scope} do
      _event = event_fixture(scope, title: "EQ Activity")
      other_scope = admin_scope_fixture(%{auxiliary: "rs"})
      _other_event = event_fixture(other_scope, title: "RS Activity")

      {:ok, _view, html} = live(conn, ~p"/admin/events")

      assert html =~ "EQ Activity"
      refute html =~ "RS Activity"
    end

    test "shows New Event button for regular admin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/events")
      assert html =~ "New Event"
    end

    test "deletes an event on confirm", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/admin/events")

      assert has_element?(view, "#event-#{event.id}")

      view
      |> element("#event-#{event.id} button", "Delete")
      |> render_click()

      refute has_element?(view, "#event-#{event.id}")
    end
  end

  describe "new event form" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{conn: log_in_user(conn, scope.user), scope: scope}
    end

    test "renders form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/events/new")
      assert has_element?(view, "#event-form")
    end

    test "shows validation error when title is blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/events/new")

      html =
        view
        |> form("#event-form", event: %{title: "", starts_on: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "creates event and redirects on valid submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/events/new")

      view
      |> form("#event-form", event: %{title: "New Activity", starts_on: "2026-06-15"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/events")
    end
  end

  describe "edit event form" do
    setup %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      event = event_fixture(scope, title: "Original Title")
      %{conn: log_in_user(conn, scope.user), scope: scope, event: event}
    end

    test "renders form with existing values", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")
      assert has_element?(view, "#event-form")
      assert render(view) =~ "Original Title"
    end

    test "updates event and redirects on valid submit", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      view
      |> form("#event-form", event: %{title: "Updated Title"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/events")
    end
  end
end
