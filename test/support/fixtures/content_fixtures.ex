defmodule SeventhWardEq.ContentFixtures do
  @moduledoc """
  Test helpers for creating entities via the `SeventhWardEq.Content` context.
  """

  import SeventhWardEq.AccountsFixtures

  alias SeventhWardEq.Accounts.{Scope, User}
  alias SeventhWardEq.Content
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
  Creates a post via the Content context.
  """
  def post_fixture(scope, attrs \\ %{}) do
    {:ok, post} =
      Content.create_post(
        scope,
        Map.merge(%{title: "Test Post", body: "<p>Hello</p>"}, Map.new(attrs))
      )

    post
  end
end
