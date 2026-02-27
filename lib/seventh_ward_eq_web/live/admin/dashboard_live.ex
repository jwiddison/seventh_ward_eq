defmodule SeventhWardEqWeb.Admin.DashboardLive do
  @moduledoc """
  Admin portal landing page.

  Shows content counts for the current admin's auxiliary.
  Superadmin sees totals across all auxiliaries.
  """

  use SeventhWardEqWeb, :live_view

  alias SeventhWardEq.Content
  alias SeventhWardEq.Events

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    {post_count, event_count} = load_counts(scope)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:current_section, :dashboard)
     |> assign(:post_count, post_count)
     |> assign(:event_count, event_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <Layouts.admin_shell current_scope={@current_scope} current_section={@current_section}>
        <div class="p-8">
          <h1 class="text-2xl font-bold text-base-content mb-6">Dashboard</h1>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 max-w-lg">
            <div class="rounded-xl border border-base-300 bg-base-200/50 p-6">
              <p class="text-sm text-base-content/50 font-medium mb-1">Posts</p>
              <p class="text-4xl font-bold text-base-content">{@post_count}</p>
              <.link
                navigate={~p"/admin/posts"}
                class="mt-3 inline-block text-sm text-primary hover:underline"
              >
                View all →
              </.link>
            </div>

            <div class="rounded-xl border border-base-300 bg-base-200/50 p-6">
              <p class="text-sm text-base-content/50 font-medium mb-1">Events</p>
              <p class="text-4xl font-bold text-base-content">{@event_count}</p>
              <.link
                navigate={~p"/admin/events"}
                class="mt-3 inline-block text-sm text-primary hover:underline"
              >
                View all →
              </.link>
            </div>
          </div>
        </div>
      </Layouts.admin_shell>
    </Layouts.app>
    """
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  @spec load_counts(map()) :: {non_neg_integer(), non_neg_integer()}
  defp load_counts(%{user: %{role: "superadmin"}}) do
    {length(Content.list_all_posts()), length(Events.list_all_events())}
  end

  defp load_counts(%{user: %{auxiliary: aux}}) do
    {length(Content.list_posts(aux)), length(Events.list_events(aux))}
  end
end
