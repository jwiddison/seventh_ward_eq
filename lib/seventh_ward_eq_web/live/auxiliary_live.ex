defmodule SeventhWardEqWeb.AuxiliaryLive do
  @moduledoc """
  Public landing page for each auxiliary (e.g. /eq, /rs, /youth).

  Displays an interactive monthly calendar and a feed of upcoming events
  and recent posts for the auxiliary. No authentication is required.

  URL params:
  - `?month=YYYY-MM` — navigate to a different month
  - `?date=YYYY-MM-DD` — select a day to see its events in a detail panel
  """

  use SeventhWardEqWeb, :live_view

  alias SeventhWardEq.Auxiliary
  alias SeventhWardEq.Calendar.Layout
  alias SeventhWardEq.Content
  alias SeventhWardEq.Events
  alias SeventhWardEqWeb.CalendarComponents

  @upcoming_events_limit 8
  @recent_posts_limit 5

  @aux_border_classes %{
    "blue" => "border-l-blue-500",
    "green" => "border-l-green-600",
    "purple" => "border-l-purple-500",
    "amber" => "border-l-amber-400",
    "orange" => "border-l-orange-500"
  }

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"slug" => slug}, _session, socket) do
    case Auxiliary.get_by_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/eq")}

      auxiliary ->
        {:ok,
         socket
         |> assign(:auxiliary, auxiliary)
         |> assign(:aux_border_class, Map.get(@aux_border_classes, auxiliary.color, "border-l-primary"))
         |> assign(:page_title, auxiliary.name)}
    end
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(_params, _uri, %{assigns: %{live_action: :not_found}} = socket) do
    {:noreply, socket}
  end

  def handle_params(params, _uri, socket) do
    auxiliary = socket.assigns.auxiliary
    today = Date.utc_today()

    current_month = parse_month_param(params["month"], today)
    selected_date = parse_date_param(params["date"])

    events = Events.list_events_for_month(auxiliary.slug, current_month.year, current_month.month)
    week_layout = Layout.build(events, current_month)
    upcoming_events = Events.list_upcoming_events(auxiliary.slug, @upcoming_events_limit)
    posts = Content.list_posts(auxiliary.slug) |> Enum.take(@recent_posts_limit)

    event_dates =
      Enum.reduce(events, MapSet.new(), fn event, acc ->
        end_date = event.ends_on || event.starts_on
        Enum.reduce(Date.range(event.starts_on, end_date), acc, &MapSet.put(&2, &1))
      end)

    selected_events =
      if selected_date do
        Enum.filter(events, &date_covers_event?(&1, selected_date))
      else
        []
      end

    {:noreply,
     socket
     |> assign(:current_month, current_month)
     |> assign(:selected_date, selected_date)
     |> assign(:week_layout, week_layout)
     |> assign(:upcoming_events, upcoming_events)
     |> assign(:posts, posts)
     |> assign(:event_dates, event_dates)
     |> assign(:selected_events, selected_events)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-base-100">
        <%!-- Page header --%>
        <header class="border-b border-base-300 px-4 py-5 sm:px-6 lg:px-8">
          <div class="mx-auto max-w-6xl flex items-center justify-between">
            <div class={["pl-3 border-l-4", @aux_border_class]}>
              <p class="text-xs uppercase tracking-widest text-base-content/40">Seventh Ward</p>
              <h1 class="text-2xl font-bold text-base-content tracking-tight">
                {@auxiliary.name}
              </h1>
            </div>
            <Layouts.theme_toggle />
          </div>
        </header>

        <%!-- Main content: two-column on desktop, stacked on mobile --%>
        <div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
          <div class="grid grid-cols-1 lg:grid-cols-[2fr_1fr] gap-8 items-start">
            <%!-- Left: Calendar --%>
            <section id="calendar-section" aria-label="Monthly calendar">
              <CalendarComponents.month_calendar
                weeks={@week_layout}
                current_month={@current_month}
                selected_date={@selected_date}
                auxiliary_slug={@auxiliary.slug}
                color={@auxiliary.color}
                event_dates={@event_dates}
              />

              <%!-- Selected day event list --%>
              <%= if @selected_date do %>
                <div id="selected-day-panel" class="mt-4 p-4 rounded-xl border border-base-300 bg-base-200/50">
                  <h3 class="text-sm font-semibold text-base-content mb-3">
                    {format_date(@selected_date)}
                  </h3>
                  <%= if @selected_events == [] do %>
                    <p class="text-sm text-base-content/50 italic">No events this day.</p>
                  <% else %>
                    <ul class="space-y-2">
                      <%= for event <- @selected_events do %>
                        <li class="flex gap-3 text-sm">
                          <span class="mt-0.5 shrink-0 text-base-content/40">
                            {format_event_time(event)}
                          </span>
                          <span class="font-medium text-base-content">{event.title}</span>
                        </li>
                      <% end %>
                    </ul>
                  <% end %>
                </div>
              <% end %>
            </section>

            <%!-- Right: Feed --%>
            <aside id="feed-section" class="space-y-6">
              <%!-- Upcoming events --%>
              <section aria-label="Upcoming events">
                <h2 class="text-sm font-semibold uppercase tracking-wider text-base-content/50 mb-3">
                  Upcoming Events
                </h2>
                <%= if @upcoming_events == [] do %>
                  <p class="text-sm text-base-content/50 italic">No upcoming events.</p>
                <% else %>
                  <ul class="space-y-3">
                    <%= for event <- @upcoming_events do %>
                      <li class="rounded-lg border border-base-300 bg-base-100 p-3 hover:bg-base-200/50 transition-colors shadow-sm">
                        <p class="font-medium text-base-content text-sm leading-snug">{event.title}</p>
                        <p class="text-xs text-base-content/50 mt-1">
                          {format_event_date_range(event)}
                          <%= if event.location do %>
                            · {event.location}
                          <% end %>
                        </p>
                      </li>
                    <% end %>
                  </ul>
                <% end %>
              </section>

              <%!-- Recent posts --%>
              <section aria-label="Recent posts">
                <h2 class="text-sm font-semibold uppercase tracking-wider text-base-content/50 mb-3">
                  Recent Posts
                </h2>
                <%= if @posts == [] do %>
                  <p class="text-sm text-base-content/50 italic">No posts yet.</p>
                <% else %>
                  <ul class="space-y-3">
                    <%= for post <- @posts do %>
                      <li class="rounded-lg border border-base-300 bg-base-100 p-3 hover:bg-base-200/50 transition-colors shadow-sm">
                        <p class="font-medium text-base-content text-sm leading-snug">{post.title}</p>
                        <p class="text-xs text-base-content/50 mt-1">
                          {format_posted_at(post.inserted_at)}
                        </p>
                      </li>
                    <% end %>
                  </ul>
                <% end %>
              </section>
            </aside>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  @spec date_covers_event?(term(), Date.t()) :: boolean()
  defp date_covers_event?(event, date) do
    event_end = event.ends_on || event.starts_on
    Date.compare(event.starts_on, date) != :gt and Date.compare(event_end, date) != :lt
  end

  @spec format_date(Date.t()) :: String.t()
  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %-d, %Y")
  end

  @spec format_event_date_range(term()) :: String.t()
  defp format_event_date_range(event) do
    start_str = Calendar.strftime(event.starts_on, "%b %-d")

    if event.ends_on && event.ends_on != event.starts_on do
      end_str = Calendar.strftime(event.ends_on, "%b %-d")
      "#{start_str} – #{end_str}"
    else
      start_str
    end
  end

  @spec format_event_time(term()) :: String.t()
  defp format_event_time(event) do
    if event.start_time do
      Calendar.strftime(event.start_time, "%-I:%M %p")
    else
      "All day"
    end
  end

  @spec format_posted_at(DateTime.t()) :: String.t()
  defp format_posted_at(datetime) do
    Calendar.strftime(datetime, "%b %-d, %Y")
  end

  @spec parse_month_param(String.t() | nil, Date.t()) :: Date.t()
  defp parse_month_param(nil, today), do: today

  defp parse_month_param(month_str, today) do
    case Date.from_iso8601("#{month_str}-01") do
      {:ok, date} -> date
      _ -> today
    end
  end

  @spec parse_date_param(String.t() | nil) :: Date.t() | nil
  defp parse_date_param(nil), do: nil

  defp parse_date_param(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
