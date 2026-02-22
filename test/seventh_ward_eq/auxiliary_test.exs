defmodule SeventhWardEq.AuxiliaryTest do
  use ExUnit.Case, async: true

  alias SeventhWardEq.Auxiliary

  doctest Auxiliary

  describe "all/0" do
    test "returns exactly 5 auxiliaries" do
      assert length(Auxiliary.all()) == 5
    end

    test "every entry has name, slug, and color" do
      for aux <- Auxiliary.all() do
        assert is_binary(aux.name)
        assert is_binary(aux.slug)
        assert is_binary(aux.color)
      end
    end
  end

  describe "real_slugs/0" do
    test "returns 5 slugs" do
      assert Auxiliary.real_slugs() == ["eq", "rs", "young-men", "young-women", "primary"]
    end
  end

  describe "get_by_slug/1" do
    test "returns real auxiliary by slug" do
      assert %{name: "Elder's Quorum"} = Auxiliary.get_by_slug("eq")
    end

    test "returns combined auxiliary by slug" do
      assert %{name: "Youth", members: ["young-men", "young-women"]} =
               Auxiliary.get_by_slug("youth")
    end

    test "returns nil for unknown slug" do
      assert Auxiliary.get_by_slug("unknown") == nil
    end
  end

  describe "resolve/1" do
    test "real slug resolves to itself" do
      assert Auxiliary.resolve("eq") == ["eq"]
      assert Auxiliary.resolve("primary") == ["primary"]
    end

    test "youth expands to its member slugs" do
      assert Auxiliary.resolve("youth") == ["young-men", "young-women"]
    end
  end
end
