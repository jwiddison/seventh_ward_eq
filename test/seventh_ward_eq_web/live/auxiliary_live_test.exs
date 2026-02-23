defmodule SeventhWardEqWeb.AuxiliaryLiveTest do
  use SeventhWardEqWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SeventhWardEq.ContentFixtures
  import SeventhWardEq.EventsFixtures, only: [event_fixture: 2]

  describe "unknown slug" do
    test "redirects to /eq", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/eq"}}} = live(conn, ~p"/unknown-aux")
    end
  end

  describe "valid slug" do
    test "renders the auxiliary name", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/eq")
      assert html =~ "Elder&#39;s Quorum"
    end

    test "shows the calendar section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eq")
      assert has_element?(view, "#calendar-section")
    end

    test "shows the feed section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eq")
      assert has_element?(view, "#feed-section")
    end

    test "shows 'No upcoming events' when there are none", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/eq")
      assert html =~ "No upcoming events"
    end

    test "shows 'No posts yet' when there are none", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/eq")
      assert html =~ "No posts yet"
    end
  end

  describe "upcoming events and posts feed" do
    setup do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      %{scope: scope}
    end

    test "lists upcoming events in the feed", %{conn: conn, scope: scope} do
      _event = event_fixture(scope, title: "Sunday Lesson", starts_on: ~D[2099-06-15])

      {:ok, _view, html} = live(conn, ~p"/eq")
      assert html =~ "Sunday Lesson"
    end

    test "shows date range for multi-day events", %{conn: conn, scope: scope} do
      _event =
        event_fixture(scope,
          title: "Youth Conference",
          starts_on: ~D[2099-06-10],
          ends_on: ~D[2099-06-12]
        )

      {:ok, _view, html} = live(conn, ~p"/eq")
      assert html =~ "Youth Conference"
      assert html =~ "Jun 10"
      assert html =~ "Jun 12"
    end

    test "lists recent posts in the feed", %{conn: conn, scope: scope} do
      _post = post_fixture(scope, title: "Ward Newsletter")

      {:ok, _view, html} = live(conn, ~p"/eq")
      assert html =~ "Ward Newsletter"
    end
  end

  describe "month navigation" do
    test "accepts a valid ?month param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/eq?month=2026-03")
      assert html =~ "March 2026"
    end

    test "falls back to current month for an invalid ?month param", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eq?month=not-a-date")
      assert has_element?(view, "#calendar-section")
    end
  end

  describe "date selection" do
    test "shows the selected day panel when ?date param is present", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eq?date=2026-06-15")
      assert has_element?(view, "#selected-day-panel")
      assert render(view) =~ "Monday, June 15, 2026"
    end

    test "shows 'No events this day' when selected date has no events", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/eq?date=2026-06-15")
      assert html =~ "No events this day"
    end

    test "shows events on the selected date", %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      _event = event_fixture(scope, title: "Home Evening", starts_on: ~D[2026-06-15])

      {:ok, _view, html} = live(conn, ~p"/eq?date=2026-06-15")
      assert html =~ "Home Evening"
    end

    test "shows event time for timed events", %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})

      _event =
        event_fixture(scope,
          title: "Morning Meeting",
          starts_on: ~D[2026-06-15],
          start_time: ~T[09:00:00]
        )

      {:ok, _view, html} = live(conn, ~p"/eq?month=2026-06&date=2026-06-15")
      assert html =~ "Morning Meeting"
      assert html =~ "9:00"
    end

    test "shows 'All day' for events without a start time", %{conn: conn} do
      scope = admin_scope_fixture(%{auxiliary: "eq"})
      _event = event_fixture(scope, title: "All Day Event", starts_on: ~D[2026-06-15])

      {:ok, _view, html} = live(conn, ~p"/eq?month=2026-06&date=2026-06-15")
      assert html =~ "All day"
    end

    test "ignores an invalid ?date param", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eq?date=not-a-date")
      refute has_element?(view, "#selected-day-panel")
    end
  end
end
