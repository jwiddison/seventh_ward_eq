defmodule SeventhWardEqWeb.Admin.PostLive do
  @moduledoc """
  Admin LiveView for managing posts.

  Handles three live actions on the same LiveView module:
  - `:index` — list all posts for the admin's auxiliary
  - `:new`   — create a new post
  - `:edit`  — update an existing post

  Superadmin sees all posts with auxiliary labels. Regular admins see only
  their own auxiliary's posts.
  """

  use SeventhWardEqWeb, :live_view

  alias SeventhWardEq.Content
  alias SeventhWardEq.Content.Post

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :posts, [])}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <Layouts.admin_shell current_scope={@current_scope}>
        <div class="p-8">
          <%= if @live_action == :index do %>
            <.post_index posts={@posts} current_scope={@current_scope} />
          <% else %>
            <.post_form form={@form} live_action={@live_action} />
          <% end %>
        </div>
      </Layouts.admin_shell>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset = Content.change_post(form_post(socket), post_params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.live_action do
        :new -> Content.create_post(scope, post_params)
        :edit -> Content.update_post(socket.assigns.post, scope, post_params)
      end

    case result do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, flash_message(socket.assigns.live_action))
         |> push_navigate(to: ~p"/admin/posts")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    post = Content.get_post!(String.to_integer(id))

    case Content.delete_post(post, socket.assigns.current_scope) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post deleted.")
         |> assign(:posts, load_posts(socket.assigns.current_scope))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete post.")}
    end
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Posts")
    |> assign(:posts, load_posts(socket.assigns.current_scope))
    |> assign(:form, nil)
    |> assign(:post, nil)
  end

  defp apply_action(socket, :new, _params) do
    post = %Post{}
    changeset = Content.change_post(post)

    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, post)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    post = Content.get_post!(String.to_integer(id))
    changeset = Content.change_post(post)

    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, post)
    |> assign(:form, to_form(changeset))
  end

  @spec load_posts(map()) :: [Post.t()]
  defp load_posts(%{user: %{role: "superadmin"}}), do: Content.list_all_posts()
  defp load_posts(%{user: %{auxiliary: aux}}), do: Content.list_posts(aux)

  @spec form_post(Phoenix.LiveView.Socket.t()) :: Post.t() | Ecto.Changeset.t()
  defp form_post(%{assigns: %{post: post}}), do: post

  @spec flash_message(atom()) :: String.t()
  defp flash_message(:new), do: "Post created."
  defp flash_message(:edit), do: "Post updated."

  # ---------------------------------------------------------------------------
  # Sub-components
  # ---------------------------------------------------------------------------

  attr :posts, :list, required: true
  attr :current_scope, :map, required: true

  defp post_index(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold text-base-content">Posts</h1>
      <%= if @current_scope.user.auxiliary do %>
        <.link
          navigate={~p"/admin/posts/new"}
          class="btn btn-primary btn-sm"
        >
          + New Post
        </.link>
      <% end %>
    </div>

    <%= if @posts == [] do %>
      <p class="text-base-content/50 italic">No posts yet.</p>
    <% else %>
      <div class="overflow-x-auto rounded-xl border border-base-300">
        <table id="posts-table" class="table w-full">
          <thead>
            <tr class="bg-base-200">
              <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">Title</th>
              <%= if @current_scope.user.role == "superadmin" do %>
                <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">
                  Auxiliary
                </th>
              <% end %>
              <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">
                Posted
              </th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            <%= for post <- @posts do %>
              <tr id={"post-#{post.id}"} class="border-t border-base-300 hover:bg-base-200/50 transition-colors">
                <td class="px-4 py-3 text-sm font-medium text-base-content">{post.title}</td>
                <%= if @current_scope.user.role == "superadmin" do %>
                  <td class="px-4 py-3 text-sm text-base-content/60">{post.auxiliary}</td>
                <% end %>
                <td class="px-4 py-3 text-sm text-base-content/50">{format_date(post.inserted_at)}</td>
                <td class="px-4 py-3">
                  <div class="flex items-center gap-2 justify-end">
                    <.link
                      navigate={~p"/admin/posts/#{post.id}/edit"}
                      class="text-xs text-primary hover:underline"
                    >
                      Edit
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={post.id}
                      data-confirm="Delete this post?"
                      class="text-xs text-error hover:underline"
                    >
                      Delete
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  attr :form, :map, required: true
  attr :live_action, :atom, required: true

  defp post_form(assigns) do
    ~H"""
    <div class="max-w-2xl">
      <div class="flex items-center gap-3 mb-6">
        <.link navigate={~p"/admin/posts"} class="text-base-content/40 hover:text-base-content">
          <.icon name="hero-arrow-left-micro" class="size-5" />
        </.link>
        <h1 class="text-2xl font-bold text-base-content">
          {if @live_action == :new, do: "New Post", else: "Edit Post"}
        </h1>
      </div>

      <.form
        for={@form}
        id="post-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-5"
      >
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:body]} type="textarea" label="Body" rows="16" required />
        <div class="flex gap-3">
          <.button type="submit" phx-disable-with="Saving…" class="btn btn-primary">
            {if @live_action == :new, do: "Create Post", else: "Save Changes"}
          </.button>
          <.link navigate={~p"/admin/posts"} class="btn btn-ghost">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @spec format_date(DateTime.t()) :: String.t()
  defp format_date(dt), do: Calendar.strftime(dt, "%b %-d, %Y")
end
