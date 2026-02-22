defmodule SeventhWardEq.Auxiliary do
  @moduledoc """
  Hard-coded auxiliary (group) definitions for the Seventh Ward.

  Auxiliaries are a fixed set — they will never change, so there is no
  DB table or seeding step. Slugs are stored directly on `users`, `posts`,
  and `events` rows as plain strings.
  """

  @typedoc "A real auxiliary entry (one of the five groups)."
  @type auxiliary :: %{name: String.t(), slug: String.t(), color: String.t()}

  @typedoc "A combined (virtual) auxiliary entry."
  @type combined :: %{name: String.t(), slug: String.t(), members: [String.t()]}

  @auxiliaries [
    %{name: "Elder's Quorum", slug: "eq", color: "blue"},
    %{name: "Relief Society", slug: "rs", color: "purple"},
    %{name: "Young Men", slug: "young-men", color: "green"},
    %{name: "Young Women", slug: "young-women", color: "amber"},
    %{name: "Primary", slug: "primary", color: "orange"}
  ]

  # Virtual combined auxiliary — not a real auxiliary; maps to a multi-slug query.
  @combined [
    %{name: "Youth", slug: "youth", members: ["young-men", "young-women"]}
  ]

  @doc """
  Returns all real auxiliaries.

  ## Examples

      iex> all = SeventhWardEq.Auxiliary.all()
      iex> length(all)
      5
      iex> hd(all).slug
      "eq"

  """
  @spec all() :: [auxiliary()]
  def all, do: @auxiliaries

  @doc """
  Returns all real auxiliary slugs.

  ## Examples

      iex> SeventhWardEq.Auxiliary.real_slugs()
      ["eq", "rs", "young-men", "young-women", "primary"]

  """
  @spec real_slugs() :: [String.t()]
  def real_slugs, do: Enum.map(@auxiliaries, & &1.slug)

  @doc """
  Returns the auxiliary (or combined) entry for the given slug, or `nil` if not found.

  ## Examples

      iex> SeventhWardEq.Auxiliary.get_by_slug("eq")
      %{name: "Elder's Quorum", slug: "eq", color: "blue"}

      iex> SeventhWardEq.Auxiliary.get_by_slug("youth")
      %{name: "Youth", slug: "youth", members: ["young-men", "young-women"]}

      iex> SeventhWardEq.Auxiliary.get_by_slug("unknown")
      nil

  """
  @spec get_by_slug(String.t()) :: auxiliary() | combined() | nil
  def get_by_slug(slug), do: Enum.find(@auxiliaries ++ @combined, &(&1.slug == slug))

  @doc """
  Resolves a slug to the list of real auxiliary slugs it covers.

  Combined slugs expand to their member slugs. Real slugs return `[slug]`.

  ## Examples

      iex> SeventhWardEq.Auxiliary.resolve("eq")
      ["eq"]

      iex> SeventhWardEq.Auxiliary.resolve("youth")
      ["young-men", "young-women"]

  """
  @spec resolve(String.t()) :: [String.t()]
  def resolve(slug) do
    case Enum.find(@combined, &(&1.slug == slug)) do
      %{members: members} -> members
      nil -> [slug]
    end
  end
end
