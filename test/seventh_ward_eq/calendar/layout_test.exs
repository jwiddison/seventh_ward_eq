defmodule SeventhWardEq.Calendar.LayoutTest do
  use ExUnit.Case, async: true

  alias SeventhWardEq.Calendar.Layout

  doctest Layout

  # Helper to build a minimal event map matching the Layout.event() type.
  defp event(attrs) do
    Map.merge(%{title: "Test", starts_on: ~D[2026-03-01], ends_on: nil}, attrs)
  end

  describe "build/2 — week structure" do
    test "March 2026 produces 5 weeks" do
      weeks = Layout.build([], ~D[2026-03-15])
      assert length(weeks) == 5
    end

    test "February 2026 produces 4 weeks" do
      weeks = Layout.build([], ~D[2026-02-01])
      assert length(weeks) == 4
    end

    test "each week has exactly 7 days" do
      weeks = Layout.build([], ~D[2026-03-01])
      assert Enum.all?(weeks, &(length(&1.days) == 7))
    end

    test "first day of every week is a Sunday" do
      weeks = Layout.build([], ~D[2026-03-01])

      assert Enum.all?(weeks, fn week ->
               # day_of_week Sunday = 7 (Elixir default)
               Date.day_of_week(hd(week.days)) == 7
             end)
    end

    test "last day of every week is a Saturday" do
      weeks = Layout.build([], ~D[2026-03-01])

      assert Enum.all?(weeks, fn week ->
               # day_of_week Saturday = 6
               Date.day_of_week(List.last(week.days)) == 6
             end)
    end

    test "first week contains the first day of the month" do
      weeks = Layout.build([], ~D[2026-03-01])
      first_week_dates = hd(weeks).days
      assert ~D[2026-03-01] in first_week_dates
    end

    test "last week contains the last day of the month" do
      weeks = Layout.build([], ~D[2026-03-01])
      last_week_dates = List.last(weeks).days
      assert ~D[2026-03-31] in last_week_dates
    end

    test "weeks with no events have max_lanes of 0" do
      weeks = Layout.build([], ~D[2026-03-01])
      assert Enum.all?(weeks, &(&1.max_lanes == 0))
    end
  end

  describe "build/2 — single-day event" do
    test "event on a Wednesday (Mar 4, 2026) lands in col_start 4" do
      # Mar 4 is a Wednesday; col 1=Sun … col 4=Wed
      e = event(%{starts_on: ~D[2026-03-04], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])

      [seg] = Enum.flat_map(weeks, & &1.segments)
      assert seg.col_start == 4
      assert seg.col_span == 1
    end

    test "single-day event has continues_before and continues_after as false" do
      e = event(%{starts_on: ~D[2026-03-10], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])

      [seg] = Enum.flat_map(weeks, & &1.segments)
      refute seg.continues_before
      refute seg.continues_after
    end

    test "event is assigned row 2" do
      e = event(%{starts_on: ~D[2026-03-04], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])

      [seg] = Enum.flat_map(weeks, & &1.segments)
      assert seg.row == 2
    end

    test "week with one event has max_lanes of 1" do
      e = event(%{starts_on: ~D[2026-03-04], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])

      week = Enum.find(weeks, &(~D[2026-03-04] in &1.days))
      assert week.max_lanes == 1
    end
  end

  describe "build/2 — multi-day event within one week" do
    test "3-day event (Mon Mar 2 – Wed Mar 4) spans cols 2–4, col_span 3" do
      e = event(%{starts_on: ~D[2026-03-02], ends_on: ~D[2026-03-04]})
      weeks = Layout.build([e], ~D[2026-03-01])

      [seg] = Enum.flat_map(weeks, & &1.segments)
      assert seg.col_start == 2
      assert seg.col_span == 3
    end
  end

  describe "build/2 — multi-day event spanning two weeks" do
    test "event Fri Mar 6 – Mon Mar 9 produces two segments" do
      e = event(%{starts_on: ~D[2026-03-06], ends_on: ~D[2026-03-09]})
      weeks = Layout.build([e], ~D[2026-03-01])
      all_segs = Enum.flat_map(weeks, & &1.segments)
      assert length(all_segs) == 2
    end

    test "first segment continues_after is true, second continues_before is true" do
      e = event(%{starts_on: ~D[2026-03-06], ends_on: ~D[2026-03-09]})
      weeks = Layout.build([e], ~D[2026-03-01])
      all_segs = Enum.flat_map(weeks, & &1.segments)

      [first_seg, second_seg] = all_segs
      assert first_seg.continues_after
      assert second_seg.continues_before
      refute first_seg.continues_before
      refute second_seg.continues_after
    end

    test "first segment ends at col 7 (Saturday), second starts at col 1 (Sunday)" do
      e = event(%{starts_on: ~D[2026-03-06], ends_on: ~D[2026-03-09]})
      weeks = Layout.build([e], ~D[2026-03-01])
      all_segs = Enum.flat_map(weeks, & &1.segments)

      [first_seg, second_seg] = all_segs
      # March 6 is Friday = col 6, spans to Saturday = col 7
      assert first_seg.col_start == 6
      assert first_seg.col_span == 2
      # Second segment starts on Sunday = col 1, March 9 is Monday = col 2
      assert second_seg.col_start == 1
      assert second_seg.col_span == 2
    end
  end

  describe "build/2 — lane assignment" do
    test "two non-overlapping same-week events share lane 1 (row 2)" do
      e1 = event(%{starts_on: ~D[2026-03-02], ends_on: nil, title: "A"})
      e2 = event(%{starts_on: ~D[2026-03-04], ends_on: nil, title: "B"})
      weeks = Layout.build([e1, e2], ~D[2026-03-01])

      week = Enum.find(weeks, &(~D[2026-03-02] in &1.days))
      rows = Enum.map(week.segments, & &1.row)
      assert Enum.sort(rows) == [2, 2]
    end

    test "two overlapping same-week events go to separate lanes" do
      e1 = event(%{starts_on: ~D[2026-03-02], ends_on: ~D[2026-03-04], title: "A"})
      e2 = event(%{starts_on: ~D[2026-03-03], ends_on: ~D[2026-03-05], title: "B"})
      weeks = Layout.build([e1, e2], ~D[2026-03-01])

      week = Enum.find(weeks, &(~D[2026-03-02] in &1.days))
      rows = Enum.sort(Enum.map(week.segments, & &1.row))
      assert rows == [2, 3]
      assert week.max_lanes == 2
    end

    test "three events where two overlap get packed correctly" do
      # e1: col 1-2, e2: col 3-5, e3: col 2-4 (overlaps both)
      e1 = event(%{starts_on: ~D[2026-03-01], ends_on: ~D[2026-03-02], title: "A"})
      e2 = event(%{starts_on: ~D[2026-03-04], ends_on: ~D[2026-03-06], title: "B"})
      e3 = event(%{starts_on: ~D[2026-03-02], ends_on: ~D[2026-03-05], title: "C"})
      weeks = Layout.build([e1, e2, e3], ~D[2026-03-01])

      week = hd(weeks)
      assert week.max_lanes == 2
      rows = Enum.sort(Enum.map(week.segments, & &1.row))
      # e1 → row 2, e2 → row 2 (no overlap with e1 since col_start 4 > col_end 2)
      # e3 → row 3 (overlaps e1 and e2)
      assert rows == [2, 2, 3]
    end
  end

  describe "build/2 — edge cases" do
    test "events on adjacent-month padding cells still appear in the grid" do
      # The last week of the March 2026 grid runs Mar 29–Apr 4 (padding cells).
      # An event on Apr 1 is visible in that row and should produce a segment.
      e = event(%{starts_on: ~D[2026-04-01], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])
      all_segs = Enum.flat_map(weeks, & &1.segments)
      assert length(all_segs) == 1
    end

    test "events entirely outside the grid produce no segments" do
      # Apr 5 starts a new week that is not part of the March 2026 grid at all.
      e = event(%{starts_on: ~D[2026-04-05], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])
      all_segs = Enum.flat_map(weeks, & &1.segments)
      assert all_segs == []
    end

    test "event with ends_on nil treated as single-day" do
      e = event(%{starts_on: ~D[2026-03-10], ends_on: nil})
      weeks = Layout.build([e], ~D[2026-03-01])
      [seg] = Enum.flat_map(weeks, & &1.segments)
      assert seg.col_span == 1
    end

    test "month-long event appears in every week" do
      e = event(%{starts_on: ~D[2026-03-01], ends_on: ~D[2026-03-31]})
      weeks = Layout.build([e], ~D[2026-03-01])
      assert Enum.all?(weeks, &(length(&1.segments) == 1))
    end
  end
end
