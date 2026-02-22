defmodule SeventhWardEq.ContentTest do
  use SeventhWardEq.DataCase, async: true

  import SeventhWardEq.ContentFixtures

  alias SeventhWardEq.Content
  alias SeventhWardEq.Content.Post

  doctest Post

  setup do
    %{scope: admin_scope_fixture()}
  end

  describe "list_posts/1" do
    test "returns posts for the matching auxiliary only", %{scope: scope} do
      post = post_fixture(scope)
      other_scope = admin_scope_fixture(%{auxiliary: "rs"})
      _other_post = post_fixture(other_scope)

      result = Content.list_posts("eq")

      assert Enum.any?(result, &(&1.id == post.id))
      refute Enum.any?(result, fn p -> p.auxiliary == "rs" end)
    end

    test "returns posts for both young-men and young-women when given 'youth'", %{
      scope: _scope
    } do
      ym_scope = admin_scope_fixture(%{auxiliary: "young-men"})
      yw_scope = admin_scope_fixture(%{auxiliary: "young-women"})
      ym_post = post_fixture(ym_scope)
      yw_post = post_fixture(yw_scope)

      result = Content.list_posts("youth")
      ids = Enum.map(result, & &1.id)

      assert ym_post.id in ids
      assert yw_post.id in ids
    end

    test "returns posts ordered most-recent first", %{scope: scope} do
      post1 = post_fixture(scope, title: "First")
      post2 = post_fixture(scope, title: "Second")

      [head | _] = Content.list_posts("eq")

      assert head.id == post2.id
      assert post1.id != post2.id
    end
  end

  describe "get_post!/1" do
    test "returns the post for the given id", %{scope: scope} do
      post = post_fixture(scope)
      assert Content.get_post!(post.id) == post
    end

    test "raises Ecto.NoResultsError for unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(0) end
    end
  end

  describe "create_post/2" do
    test "creates post with valid attrs", %{scope: scope} do
      attrs = %{title: "Hello World", body: "<p>Content</p>"}
      assert {:ok, %Post{} = post} = Content.create_post(scope, attrs)
      assert post.title == "Hello World"
      assert post.body == "<p>Content</p>"
      assert post.auxiliary == scope.user.auxiliary
      assert post.author_id == scope.user.id
    end

    test "returns error changeset when title is blank", %{scope: scope} do
      assert {:error, changeset} = Content.create_post(scope, %{title: "", body: "<p>x</p>"})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when body is blank", %{scope: scope} do
      assert {:error, changeset} = Content.create_post(scope, %{title: "T", body: ""})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when title is too long", %{scope: scope} do
      long_title = String.duplicate("a", 256)
      assert {:error, changeset} = Content.create_post(scope, %{title: long_title, body: "x"})
      assert %{title: _} = errors_on(changeset)
    end
  end

  describe "update_post/3" do
    test "updates title and body", %{scope: scope} do
      post = post_fixture(scope)
      assert {:ok, updated} = Content.update_post(post, scope, %{title: "New Title"})
      assert updated.title == "New Title"
      assert updated.auxiliary == post.auxiliary
    end

    test "returns error changeset with invalid attrs", %{scope: scope} do
      post = post_fixture(scope)
      assert {:error, changeset} = Content.update_post(post, scope, %{title: ""})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_post/2" do
    test "deletes the post", %{scope: scope} do
      post = post_fixture(scope)
      assert {:ok, %Post{}} = Content.delete_post(post, scope)
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(post.id) end
    end
  end

  describe "change_post/2" do
    test "returns a changeset", %{scope: _scope} do
      post = %Post{auxiliary: "eq"}
      assert %Ecto.Changeset{} = Content.change_post(post)
    end
  end

  describe "post nullifies author_id when user deleted" do
    test "author_id becomes nil after user deletion", %{scope: scope} do
      post = post_fixture(scope)
      assert post.author_id == scope.user.id

      SeventhWardEq.Repo.delete!(scope.user)

      updated = Content.get_post!(post.id)
      assert updated.author_id == nil
    end
  end
end
