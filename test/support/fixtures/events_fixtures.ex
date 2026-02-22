defmodule SeventhWardEq.EventsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `SeventhWardEq.Events` context.
  """

  import SeventhWardEq.AccountsFixtures

  alias SeventhWardEq.Accounts.{Scope, User}
  alias SeventhWardEq.Events
  alias SeventhWardEq.Repo

  @doc """
  Creates a scope for an admin user with the given auxiliary (default: "eq").
  Builds on top of `user_fixture/1` so the user is confirmed.
  """
  def admin_scope_fixture(attrs \\ %{}) do
    user = user_fixture()

    user =
      user
      |> User.admin_changeset(Map.merge(%{role: "admin", auxiliary: "eq"}, attrs))
      |> Repo.update!()

    Scope.for_user(user)
  end

  @doc """
  Creates an event via the Events context.
  """
  def event_fixture(scope, attrs \\ %{}) do
    {:ok, event} =
      Events.create_event(
        scope,
        Map.merge(%{title: "Test Event", starts_on: ~D[2026-06-01]}, Map.new(attrs))
      )

    event
  end
end
