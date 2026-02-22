defmodule SeventhWardEq.Content.Post do
  @moduledoc """
  Schema for a post (a rich-text article) belonging to one auxiliary.

  `author_id` and `auxiliary` are set programmatically by the context when
  creating a post — they are NOT cast from user-submitted form params.
  `body` holds sanitized HTML produced by the TipTap editor (sanitization
  applied in Phase 5 when TipTap is integrated).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias SeventhWardEq.Auxiliary

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          body: String.t() | nil,
          author_id: integer() | nil,
          auxiliary: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "posts" do
    field :title, :string
    # :text in DB; :string in schema per Ecto convention
    field :body, :string
    # Nullable: set to NULL when the author user is deleted (ON DELETE SET NULL)
    field :author_id, :integer
    # Set from current_user.auxiliary at creation — never cast from form params
    field :auxiliary, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for user-editable fields (`title` and `body`).

  `author_id` and `auxiliary` must NOT appear in `attrs` — they are set
  programmatically by the context before calling this function.

  ## Examples

      iex> SeventhWardEq.Content.Post.changeset(%SeventhWardEq.Content.Post{auxiliary: "eq"}, %{title: "Hello", body: "<p>World</p>"}).valid?
      true

      iex> SeventhWardEq.Content.Post.changeset(%SeventhWardEq.Content.Post{auxiliary: "eq"}, %{title: "", body: ""}).valid?
      false

  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body])
    |> validate_required([:title, :body])
    |> validate_length(:title, max: 255)
    |> validate_auxiliary()
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  @spec validate_auxiliary(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_auxiliary(changeset) do
    case get_field(changeset, :auxiliary) do
      nil -> add_error(changeset, :auxiliary, "can't be blank")
      _slug -> validate_inclusion(changeset, :auxiliary, Auxiliary.real_slugs())
    end
  end
end
