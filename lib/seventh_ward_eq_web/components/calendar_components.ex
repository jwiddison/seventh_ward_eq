defmodule SeventhWardEqWeb.CalendarComponents do
  @moduledoc """
  Function components for rendering the monthly calendar grid.

  CSS Grid column/row placement uses **inline styles** for dynamic numeric
  values (e.g. `grid-column: 2 / span 4`) because Tailwind v4's source scanner
  only picks up statically-written class names. Everything else (color, rounding,
  typography) uses static Tailwind classes.

  Color classes are defined as a module-attribute map with literal class strings
  so the Tailwind scanner picks them up at build time.
  """

  use SeventhWardEqWeb, :html

  # Must be literal class strings so the Tailwind v4 scanner picks them up.
  @color_classes %{
    "blue" => "bg-blue-500 text-white",
    "green" => "bg-green-600 text-white",
    "purple" => "bg-purple-500 text-white",
    "amber" => "bg-amber-400 text-gray-900",
    "orange" => "bg-orange-500 text-white"
  }

  @doc """
  Renders the full month calendar grid with navigation controls.

  Accepts pre-computed `weeks` from `SeventhWardEq.Calendar.Layout.build/2`.
  """
  attr :weeks, :list, required: true, doc: "pre-computed week maps from Calendar.Layout"
  attr :current_month, :any, required: true, doc: "Date.t() in the displayed month"
  attr :selected_date, :any, default: nil, doc: "currently selected Date.t() or nil"
  attr :auxiliary_slug, :string, required: true
  attr :color, :string, required: true, doc: "auxiliary color key (blue, green, etc.)"
  attr :event_dates, :any, default: nil, doc: "MapSet of Date.t() that have events"

  def month_calendar(assigns) do
    ~H"""
    <div id="month-calendar" class="select-none">
      <%!-- Month navigation header --%>
      <div class="flex items-center justify-between mb-3">
        <.link
          id="prev-month-link"
          patch={"?month=#{prev_month_param(@current_month)}"}
          class="p-2 rounded-lg hover:bg-base-200 transition-colors text-base-content/60 hover:text-base-content"
          aria-label="Previous month"
        >
          <.icon name="hero-chevron-left" class="size-5" />
        </.link>

        <h2 class="text-lg font-semibold text-base-content">
          {format_month(@current_month)}
        </h2>

        <.link
          id="next-month-link"
          patch={"?month=#{next_month_param(@current_month)}"}
          class="p-2 rounded-lg hover:bg-base-200 transition-colors text-base-content/60 hover:text-base-content"
          aria-label="Next month"
        >
          <.icon name="hero-chevron-right" class="size-5" />
        </.link>
      </div>

      <%!-- Day-of-week header row --%>
      <div class="grid grid-cols-7 mb-1">
        <%= for header <- ~w[Sun Mon Tue Wed Thu Fri Sat] do %>
          <div class="text-center text-xs font-medium text-base-content/50 py-1">
            {header}
          </div>
        <% end %>
      </div>

      <%!-- Week rows --%>
      <div class="border border-base-300 rounded-xl overflow-hidden">
        <%= for {week, week_idx} <- Enum.with_index(@weeks) do %>
          <.week_row
            week={week}
            current_month={@current_month}
            selected_date={@selected_date}
            auxiliary_slug={@auxiliary_slug}
            color={@color}
            event_dates={@event_dates}
            last={week_idx == length(@weeks) - 1}
          />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders one week row as a CSS Grid with day-number cells in row 1
  and event bars in rows 2+.
  """
  attr :week, :map, required: true
  attr :current_month, :any, required: true
  attr :selected_date, :any, default: nil
  attr :auxiliary_slug, :string, required: true
  attr :color, :string, required: true
  attr :event_dates, :any, default: nil
  attr :last, :boolean, default: false

  def week_row(assigns) do
    ~H"""
    <div
      class={["grid grid-cols-7 border-base-300", !@last && "border-b"]}
      style={"grid-template-rows: 2.5rem repeat(#{@week.max_lanes}, 1.5rem) 0.25rem"}
    >
      <%!-- Day-number cells (auto-placed into row 1) --%>
      <%= for date <- @week.days do %>
        <.day_cell
          date={date}
          current_month={@current_month}
          selected_date={@selected_date}
          auxiliary_slug={@auxiliary_slug}
          event_dates={@event_dates}
        />
      <% end %>

      <%!-- Event bars (explicitly placed via inline grid-column/grid-row) --%>
      <%= for seg <- @week.segments do %>
        <.event_bar segment={seg} color={@color} />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a single day-number cell. Clicking it patch-navigates to `?date=YYYY-MM-DD`.
  """
  attr :date, :any, required: true
  attr :current_month, :any, required: true
  attr :selected_date, :any, default: nil
  attr :auxiliary_slug, :string, required: true
  attr :event_dates, :any, default: nil

  def day_cell(assigns) do
    assigns =
      assign(assigns,
        in_month: assigns.date.month == assigns.current_month.month,
        is_today: assigns.date == Date.utc_today(),
        is_selected: assigns.date == assigns.selected_date,
        has_events: assigns.event_dates != nil and assigns.date in assigns.event_dates
      )

    ~H"""
    <.link
      patch={"?date=#{Date.to_iso8601(@date)}"}
      class={[
        "flex flex-col items-center justify-start pt-1 text-sm font-medium border-r border-base-300",
        "last:border-r-0 cursor-pointer transition-colors duration-100",
        @in_month && "text-base-content hover:bg-base-200/50",
        !@in_month && "text-base-content/25 hover:bg-base-200/30",
        @is_today && "font-bold",
        @is_selected && "bg-base-200"
      ]}
    >
      <span class={[
        "flex items-center justify-center size-7 rounded-full text-xs",
        @is_today && "bg-primary text-primary-content"
      ]}>
        {@date.day}
      </span>
      <%= if @has_events do %>
        <span class="size-1.5 rounded-full bg-primary mt-0.5 opacity-60"></span>
      <% end %>
    </.link>
    """
  end

  @doc """
  Renders one event segment bar with explicit CSS Grid column/row placement.

  Uses `continues_before` / `continues_after` flags to suppress rounding on
  clipped edges and show a continuation indicator. The event title is shown
  only on the first visible segment (`continues_before: false`).
  """
  attr :segment, :map, required: true
  attr :color, :string, required: true

  def event_bar(assigns) do
    assigns = assign(assigns, color_classes: Map.get(@color_classes, assigns.color, "bg-gray-400 text-white"))

    ~H"""
    <div
      class={[
        "flex items-center overflow-hidden text-xs font-medium leading-none px-1.5 mx-0.5 my-0.5",
        "cursor-default select-none z-10",
        @color_classes,
        if(@segment.continues_before, do: "rounded-l-none", else: "rounded-l"),
        if(@segment.continues_after, do: "rounded-r-none pr-0", else: "rounded-r")
      ]}
      style={"grid-column: #{@segment.col_start} / span #{@segment.col_span}; grid-row: #{@segment.row};"}
      title={@segment.event.title}
    >
      <%= if @segment.continues_before do %>
        <span class="opacity-60 mr-1 shrink-0">‹</span>
      <% end %>
      <span class={["truncate", @segment.continues_before && "ml-0"]}>
        {if @segment.continues_before, do: "", else: @segment.event.title}
      </span>
      <%= if @segment.continues_after do %>
        <span class="opacity-60 ml-auto shrink-0">›</span>
      <% end %>
    </div>
    """
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  @spec format_month(Date.t()) :: String.t()
  defp format_month(date), do: Calendar.strftime(date, "%B %Y")

  @spec prev_month_param(Date.t()) :: String.t()
  defp prev_month_param(date) do
    prev = date |> Date.beginning_of_month() |> Date.add(-1)
    Calendar.strftime(prev, "%Y-%m")
  end

  @spec next_month_param(Date.t()) :: String.t()
  defp next_month_param(date) do
    next = date |> Date.end_of_month() |> Date.add(1)
    Calendar.strftime(next, "%Y-%m")
  end
end
