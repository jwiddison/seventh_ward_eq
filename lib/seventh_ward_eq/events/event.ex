defmodule SeventhWardEq.Events.Event do
  @moduledoc """
  Schema for a calendar event belonging to one auxiliary.

  `author_id` and `auxiliary` are set programmatically by the context when
  creating an event — they are NOT cast from user-submitted form params.

  `ends_on` is nullable — absent means the event is a single day.
  `start_time` and `end_time` are nullable — absent means all-day.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias SeventhWardEq.Auxiliary

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          location: String.t() | nil,
          starts_on: Date.t() | nil,
          ends_on: Date.t() | nil,
          start_time: Time.t() | nil,
          end_time: Time.t() | nil,
          author_id: integer() | nil,
          auxiliary: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "events" do
    field :title, :string
    field :description, :string
    field :location, :string
    field :starts_on, :date
    field :ends_on, :date
    field :start_time, :time
    field :end_time, :time
    # Nullable: set to NULL when the author user is deleted (ON DELETE SET NULL)
    field :author_id, :integer
    # Set from current_user.auxiliary at creation — never cast from form params
    field :auxiliary, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for user-editable fields.

  `author_id` and `auxiliary` must NOT appear in `attrs` — they are set
  programmatically by the context before calling this function.

  ## Examples

      iex> SeventhWardEq.Events.Event.changeset(
      ...>   %SeventhWardEq.Events.Event{auxiliary: "eq"},
      ...>   %{title: "Activity Night", starts_on: ~D[2026-03-01]}
      ...> ).valid?
      true

      iex> SeventhWardEq.Events.Event.changeset(
      ...>   %SeventhWardEq.Events.Event{auxiliary: "eq"},
      ...>   %{title: ""}
      ...> ).valid?
      false

  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :location, :starts_on, :ends_on, :start_time, :end_time])
    |> validate_required([:title, :starts_on])
    |> validate_length(:title, max: 255)
    |> validate_date_range()
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

  @spec validate_date_range(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_date_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    if starts_on && ends_on && Date.compare(ends_on, starts_on) == :lt do
      add_error(changeset, :ends_on, "must be on or after the start date")
    else
      changeset
    end
  end
end
