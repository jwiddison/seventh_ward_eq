defmodule SeventhWardEq.Calendar.Layout do
  @moduledoc """
  Pure-Elixir module that converts a list of events and a month date into
  a structured list of week maps ready for rendering in a CSS-Grid calendar.

  Each week map contains:
  - `days` — list of 7 `Date.t()` values (Sunday → Saturday), including
    adjacent-month dates for partial first/last weeks.
  - `segments` — list of clipped event placements for that week, each with
    grid column/row coordinates and continuation flags.
  - `max_lanes` — number of event lanes in the week (used to compute the
    CSS Grid `grid-template-rows` height).

  This module has no database or Phoenix dependencies and is fully testable
  in isolation.
  """

  @type event :: %{
          required(:title) => String.t(),
          required(:starts_on) => Date.t(),
          required(:ends_on) => Date.t() | nil,
          optional(atom()) => term()
        }

  @type segment :: %{
          event: event(),
          col_start: 1..7,
          col_span: 1..7,
          row: pos_integer(),
          continues_before: boolean(),
          continues_after: boolean()
        }

  @type week :: %{
          days: [Date.t()],
          segments: [segment()],
          max_lanes: non_neg_integer()
        }

  @doc """
  Builds the week layout for the month containing `month_date`.

  Events spanning multiple weeks are clipped to each week row and assigned
  a lane (row) using greedy interval packing. Row 1 is reserved for day
  number cells; event bars start at row 2.

  ## Examples

      iex> events = []
      iex> weeks = SeventhWardEq.Calendar.Layout.build(events, ~D[2026-03-01])
      iex> length(weeks)
      5
      iex> hd(weeks).days |> hd() |> Date.day_of_week()
      7

  """
  @spec build([event()], Date.t()) :: [week()]
  def build(events, month_date) do
    week_days_list = build_weeks(month_date)

    Enum.map(week_days_list, fn days ->
      week_start = hd(days)
      week_end = List.last(days)

      raw_segments =
        events
        |> Enum.flat_map(&clip_to_week(&1, week_start, week_end))
        |> Enum.sort_by(&{&1.col_start, &1.col_start + &1.col_span - 1})

      {segments, max_lanes} = assign_lanes(raw_segments)

      %{days: days, segments: segments, max_lanes: max_lanes}
    end)
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  # Returns the column number (1 = Sunday, 7 = Saturday) for a given date.
  @spec day_of_week_col(Date.t()) :: 1..7
  defp day_of_week_col(date) do
    # Date.day_of_week/1 returns Monday=1 … Sunday=7
    # We want Sunday=1, Monday=2, …, Saturday=7
    dow = Date.day_of_week(date)
    rem(dow, 7) + 1
  end

  # Finds the Sunday on or before `date`.
  @spec week_start_for(Date.t()) :: Date.t()
  defp week_start_for(date) do
    col = day_of_week_col(date)
    Date.add(date, -(col - 1))
  end

  # Builds a list of 7-day lists (Sun–Sat) covering the full month.
  @spec build_weeks(Date.t()) :: [[Date.t()]]
  defp build_weeks(month_date) do
    first = %{month_date | day: 1}
    last = Date.end_of_month(month_date)
    start = week_start_for(first)

    start
    |> Stream.iterate(&Date.add(&1, 7))
    |> Stream.take_while(&(Date.compare(&1, last) != :gt))
    |> Enum.map(fn week_start ->
      Enum.map(0..6, &Date.add(week_start, &1))
    end)
  end

  # Clips an event to a single week row, returning [] if no overlap.
  # Multi-day events produce one segment per overlapping week.
  @spec clip_to_week(event(), Date.t(), Date.t()) :: [map()]
  defp clip_to_week(event, week_start, week_end) do
    event_end = event.ends_on || event.starts_on

    eff_start = latest_date(event.starts_on, week_start)
    eff_end = earliest_date(event_end, week_end)

    if Date.compare(eff_start, eff_end) == :gt do
      []
    else
      [
        %{
          event: event,
          col_start: day_of_week_col(eff_start),
          col_span: Date.diff(eff_end, eff_start) + 1,
          continues_before: Date.compare(event.starts_on, week_start) == :lt,
          continues_after: Date.compare(event_end, week_end) == :gt,
          row: nil
        }
      ]
    end
  end

  # Greedily assigns lane rows to pre-sorted segments.
  # `lanes` tracks the rightmost col_end occupied in each lane.
  # Returns {segments_with_rows, max_lanes}.
  @spec assign_lanes([map()]) :: {[segment()], non_neg_integer()}
  defp assign_lanes([]), do: {[], 0}

  defp assign_lanes(segments) do
    {assigned, lanes} =
      Enum.reduce(segments, {[], []}, fn seg, {acc, lanes} ->
        col_end = seg.col_start + seg.col_span - 1

        lane_idx = Enum.find_index(lanes, &(seg.col_start > &1))

        {row_num, new_lanes} =
          if lane_idx do
            {lane_idx + 2, List.replace_at(lanes, lane_idx, col_end)}
          else
            {length(lanes) + 2, lanes ++ [col_end]}
          end

        {acc ++ [Map.put(seg, :row, row_num)], new_lanes}
      end)

    {assigned, length(lanes)}
  end

  @spec latest_date(Date.t(), Date.t()) :: Date.t()
  defp latest_date(a, b), do: if(Date.compare(a, b) == :lt, do: b, else: a)

  @spec earliest_date(Date.t(), Date.t()) :: Date.t()
  defp earliest_date(a, b), do: if(Date.compare(a, b) == :gt, do: b, else: a)
end
