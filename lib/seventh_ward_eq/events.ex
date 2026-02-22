defmodule SeventhWardEq.Events do
  @moduledoc """
  Context for managing calendar events.

  All query functions accept an `auxiliary_slug` and resolve it via
  `SeventhWardEq.Auxiliary.resolve/1`, so the combined `"youth"` slug
  transparently queries both Young Men and Young Women events.

  `create_event/2` and `update_event/3` receive the caller's `Scope` so that
  `author_id` and `auxiliary` can be set programmatically without appearing
  in user-submitted form params.
  """

  import Ecto.Query

  alias SeventhWardEq.Accounts.Scope
  alias SeventhWardEq.Auxiliary
  alias SeventhWardEq.Events.Event
  alias SeventhWardEq.Repo

  @doc """
  Returns a changeset for tracking event changes (used to initialize LiveView forms).

  ## Examples

      change_event(%Event{auxiliary: "eq"})
      change_event(%Event{auxiliary: "eq"}, %{title: "Activity Night"})

  """
  @spec change_event(Event.t(), map()) :: Ecto.Changeset.t()
  def change_event(event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Creates a new event scoped to the calling user's auxiliary.

  `auxiliary` and `author_id` are taken from `scope.user` and are never
  cast from `attrs`.

  Returns `{:ok, event}` or `{:error, changeset}`.

  ## Examples

      create_event(scope, %{title: "Campout", starts_on: ~D[2026-07-04]})

  """
  @spec create_event(Scope.t(), map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(%Scope{} = scope, attrs) do
    %Event{author_id: scope.user.id, auxiliary: scope.user.auxiliary}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes an event.

  Returns `{:ok, event}` or `{:error, changeset}`.

  ## Examples

      delete_event(event, scope)

  """
  @spec delete_event(Event.t(), Scope.t()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def delete_event(%Event{} = event, %Scope{}) do
    Repo.delete(event)
  end

  @doc """
  Gets a single event by id. Raises `Ecto.NoResultsError` if not found.

  ## Examples

      get_event!(42)

  """
  @spec get_event!(integer()) :: Event.t()
  def get_event!(id), do: Repo.get!(Event, id)

  @doc """
  Returns all events that overlap with the given month for the given auxiliary slug.

  Handles multi-day events: an event is included if any part of it falls
  within [first day of month, last day of month]. Ordered by start date,
  then start time (nulls last).

  Accepts real slugs (e.g. `"rs"`) or the combined `"youth"` slug.

  ## Examples

      list_events_for_month("eq", 2026, 3)    # March 2026
      list_events_for_month("youth", 2026, 7)  # July 2026, both YM and YW

  """
  @spec list_events_for_month(String.t(), pos_integer(), 1..12) :: [Event.t()]
  def list_events_for_month(auxiliary_slug, year, month) do
    slugs = Auxiliary.resolve(auxiliary_slug)
    first_day = Date.new!(year, month, 1)
    last_day = Date.end_of_month(first_day)

    from(e in Event,
      where: e.auxiliary in ^slugs,
      where: e.starts_on <= ^last_day,
      where: fragment("COALESCE(?, ?)", e.ends_on, e.starts_on) >= ^first_day,
      order_by: [asc: e.starts_on, asc_nulls_last: e.start_time]
    )
    |> Repo.all()
  end

  @doc """
  Returns upcoming events (starting today or later) for the given auxiliary slug.

  Results are ordered by start date, then start time (nulls last), limited to
  `limit` rows.

  Accepts real slugs or the combined `"youth"` slug.

  ## Examples

      list_upcoming_events("eq", 5)
      list_upcoming_events("youth", 10)

  """
  @spec list_upcoming_events(String.t(), pos_integer()) :: [Event.t()]
  def list_upcoming_events(auxiliary_slug, limit) do
    slugs = Auxiliary.resolve(auxiliary_slug)
    today = Date.utc_today()

    from(e in Event,
      where: e.auxiliary in ^slugs,
      where: e.starts_on >= ^today,
      order_by: [asc: e.starts_on, asc_nulls_last: e.start_time],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Updates an existing event.

  Only user-editable fields may be changed — `auxiliary` and `author_id`
  are not modified on update.

  Returns `{:ok, event}` or `{:error, changeset}`.

  ## Examples

      update_event(event, scope, %{title: "Renamed event"})

  """
  @spec update_event(Event.t(), Scope.t(), map()) ::
          {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def update_event(%Event{} = event, %Scope{}, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end
end
