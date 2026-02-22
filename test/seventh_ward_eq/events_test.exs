defmodule SeventhWardEq.EventsTest do
  use SeventhWardEq.DataCase, async: true

  import SeventhWardEq.EventsFixtures

  alias SeventhWardEq.Events
  alias SeventhWardEq.Events.Event

  doctest Event

  setup do
    %{scope: admin_scope_fixture()}
  end

  describe "list_events_for_month/3" do
    test "returns events whose start date is within the month", %{scope: scope} do
      event = event_fixture(scope, starts_on: ~D[2026-06-15])
      result = Events.list_events_for_month("eq", 2026, 6)
      assert Enum.any?(result, &(&1.id == event.id))
    end

    test "excludes events outside the month", %{scope: scope} do
      event = event_fixture(scope, starts_on: ~D[2026-05-01])
      result = Events.list_events_for_month("eq", 2026, 6)
      refute Enum.any?(result, &(&1.id == event.id))
    end

    test "includes multi-day events that overlap the month boundary", %{scope: scope} do
      # Starts in May, ends in June
      event = event_fixture(scope, starts_on: ~D[2026-05-28], ends_on: ~D[2026-06-02])
      result = Events.list_events_for_month("eq", 2026, 6)
      assert Enum.any?(result, &(&1.id == event.id))
    end

    test "excludes multi-day events that end before the month", %{scope: scope} do
      event = event_fixture(scope, starts_on: ~D[2026-05-28], ends_on: ~D[2026-05-31])
      result = Events.list_events_for_month("eq", 2026, 6)
      refute Enum.any?(result, &(&1.id == event.id))
    end

    test "filters by auxiliary slug", %{scope: scope} do
      eq_event = event_fixture(scope, starts_on: ~D[2026-06-10])
      rs_scope = admin_scope_fixture(%{auxiliary: "rs"})
      _rs_event = event_fixture(rs_scope, starts_on: ~D[2026-06-10])

      result = Events.list_events_for_month("eq", 2026, 6)
      assert Enum.any?(result, &(&1.id == eq_event.id))
      refute Enum.any?(result, fn e -> e.auxiliary == "rs" end)
    end

    test "expands 'youth' to young-men and young-women" do
      ym_scope = admin_scope_fixture(%{auxiliary: "young-men"})
      yw_scope = admin_scope_fixture(%{auxiliary: "young-women"})
      ym_event = event_fixture(ym_scope, starts_on: ~D[2026-06-01])
      yw_event = event_fixture(yw_scope, starts_on: ~D[2026-06-05])

      result = Events.list_events_for_month("youth", 2026, 6)
      ids = Enum.map(result, & &1.id)

      assert ym_event.id in ids
      assert yw_event.id in ids
    end
  end

  describe "list_upcoming_events/2" do
    test "returns only future events", %{scope: scope} do
      past_event = event_fixture(scope, starts_on: ~D[2020-01-01])
      future_event = event_fixture(scope, starts_on: ~D[2099-01-01])

      result = Events.list_upcoming_events("eq", 10)
      ids = Enum.map(result, & &1.id)

      assert future_event.id in ids
      refute past_event.id in ids
    end

    test "respects the limit", %{scope: scope} do
      for i <- 1..5 do
        event_fixture(scope, starts_on: Date.add(Date.utc_today(), i), title: "Event #{i}")
      end

      result = Events.list_upcoming_events("eq", 3)
      assert length(result) == 3
    end
  end

  describe "get_event!/1" do
    test "returns the event for the given id", %{scope: scope} do
      event = event_fixture(scope)
      assert Events.get_event!(event.id) == event
    end

    test "raises Ecto.NoResultsError for unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(0) end
    end
  end

  describe "create_event/2" do
    test "creates event with valid attrs", %{scope: scope} do
      attrs = %{title: "Camp", starts_on: ~D[2026-07-04]}
      assert {:ok, %Event{} = event} = Events.create_event(scope, attrs)
      assert event.title == "Camp"
      assert event.starts_on == ~D[2026-07-04]
      assert event.auxiliary == scope.user.auxiliary
      assert event.author_id == scope.user.id
    end

    test "returns error changeset when title is blank", %{scope: scope} do
      assert {:error, changeset} =
               Events.create_event(scope, %{title: "", starts_on: ~D[2026-07-04]})

      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when starts_on is missing", %{scope: scope} do
      assert {:error, changeset} = Events.create_event(scope, %{title: "Camp"})
      assert %{starts_on: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when ends_on is before starts_on", %{scope: scope} do
      attrs = %{title: "Camp", starts_on: ~D[2026-07-10], ends_on: ~D[2026-07-05]}
      assert {:error, changeset} = Events.create_event(scope, attrs)
      assert %{ends_on: ["must be on or after the start date"]} = errors_on(changeset)
    end
  end

  describe "update_event/3" do
    test "updates title", %{scope: scope} do
      event = event_fixture(scope)
      assert {:ok, updated} = Events.update_event(event, scope, %{title: "Renamed"})
      assert updated.title == "Renamed"
      assert updated.auxiliary == event.auxiliary
    end

    test "returns error changeset with invalid attrs", %{scope: scope} do
      event = event_fixture(scope)
      assert {:error, changeset} = Events.update_event(event, scope, %{title: ""})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_event/2" do
    test "deletes the event", %{scope: scope} do
      event = event_fixture(scope)
      assert {:ok, %Event{}} = Events.delete_event(event, scope)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end
  end

  describe "change_event/2" do
    test "returns a changeset" do
      event = %Event{auxiliary: "eq"}
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end

  describe "event nullifies author_id when user deleted" do
    test "author_id becomes nil after user deletion", %{scope: scope} do
      event = event_fixture(scope)
      assert event.author_id == scope.user.id

      SeventhWardEq.Repo.delete!(scope.user)

      updated = Events.get_event!(event.id)
      assert updated.author_id == nil
    end
  end
end
