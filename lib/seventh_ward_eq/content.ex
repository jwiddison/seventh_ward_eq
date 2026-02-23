defmodule SeventhWardEq.Content do
  @moduledoc """
  Context for managing posts.

  All query functions accept an `auxiliary_slug` and resolve it via
  `SeventhWardEq.Auxiliary.resolve/1`, so the combined `"youth"` slug
  transparently queries both Young Men and Young Women posts.

  `create_post/2` and `update_post/3` receive the caller's `Scope` so that
  `author_id` and `auxiliary` can be set programmatically without appearing
  in user-submitted form params.
  """

  import Ecto.Query

  alias SeventhWardEq.Accounts.Scope
  alias SeventhWardEq.Auxiliary
  alias SeventhWardEq.Content.Post
  alias SeventhWardEq.Repo

  @doc """
  Returns a changeset for tracking post changes (used to initialize LiveView forms).

  ## Examples

      change_post(%Post{auxiliary: "eq"})
      change_post(%Post{auxiliary: "eq"}, %{title: "Draft title"})

  """
  @spec change_post(Post.t(), map()) :: Ecto.Changeset.t()
  def change_post(post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Creates a new post scoped to the calling user's auxiliary.

  `auxiliary` and `author_id` are taken from `scope.user` and are never
  cast from `attrs`.

  Returns `{:ok, post}` or `{:error, changeset}`.

  ## Examples

      create_post(scope, %{title: "Hello", body: "<p>World</p>"})

  """
  @spec create_post(Scope.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def create_post(%Scope{} = scope, attrs) do
    %Post{author_id: scope.user.id, auxiliary: scope.user.auxiliary}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a post.

  Returns `{:ok, post}` or `{:error, changeset}`.

  ## Examples

      delete_post(post, scope)

  """
  @spec delete_post(Post.t(), Scope.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def delete_post(%Post{} = post, %Scope{}) do
    Repo.delete(post)
  end

  @doc """
  Gets a single post by id. Raises `Ecto.NoResultsError` if not found.

  ## Examples

      get_post!(42)

  """
  @spec get_post!(integer()) :: Post.t()
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Returns all posts across every auxiliary, ordered most-recent first.

  For use by the superadmin only — regular admins should use `list_posts/1`.

  ## Examples

      list_all_posts()

  """
  @spec list_all_posts() :: [Post.t()]
  def list_all_posts do
    from(p in Post, order_by: [desc: p.inserted_at])
    |> Repo.all()
  end

  @doc """
  Returns all posts for the given auxiliary slug, ordered most-recent first.

  Accepts real slugs (e.g. `"eq"`) or the combined `"youth"` slug.

  ## Examples

      list_posts("eq")
      list_posts("youth")  # returns posts for both young-men and young-women

  """
  @spec list_posts(String.t()) :: [Post.t()]
  def list_posts(auxiliary_slug) do
    slugs = Auxiliary.resolve(auxiliary_slug)

    from(p in Post,
      where: p.auxiliary in ^slugs,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Updates an existing post.

  Only `title` and `body` may be changed — `auxiliary` and `author_id`
  are not modified on update.

  Returns `{:ok, post}` or `{:error, changeset}`.

  ## Examples

      update_post(post, scope, %{title: "Updated title"})

  """
  @spec update_post(Post.t(), Scope.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def update_post(%Post{} = post, %Scope{}, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end
end
