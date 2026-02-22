defmodule SeventhWardEqWeb.LiveHooks.Auth do
  @moduledoc """
  LiveView `on_mount` hooks for admin portal authentication.

  All admin routes are LiveView-based, so authentication is enforced here
  via `on_mount` hooks wired into `live_session` blocks in the router.
  There are no controller plugs for the admin portal.
  """

  use SeventhWardEqWeb, :verified_routes

  import Phoenix.LiveView
  import Phoenix.Component

  alias SeventhWardEq.Accounts
  alias SeventhWardEq.Accounts.Scope

  @doc """
  `on_mount` hook that requires an authenticated admin or superadmin.

  Redirects to `/admin/log-in` if no user is logged in or if the
  current user does not have `role` of `"admin"` or `"superadmin"`.
  """
  @spec require_admin(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def require_admin(_action, _params, session, socket) do
    socket = assign_current_scope(socket, session)

    case socket.assigns.current_scope do
      %{user: %{role: role}} when role in ["admin", "superadmin"] ->
        {:cont, socket}

      _ ->
        {:halt, redirect(socket, to: ~p"/admin/log-in")}
    end
  end

  @doc """
  `on_mount` hook that requires a superadmin.

  Redirects to `/admin/log-in` if unauthenticated, or to `/admin` if
  the current user is a regular admin (not superadmin).
  """
  @spec require_superadmin(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def require_superadmin(_action, _params, session, socket) do
    socket = assign_current_scope(socket, session)

    case socket.assigns.current_scope do
      %{user: %{role: "superadmin"}} ->
        {:cont, socket}

      %{user: %{}} ->
        # Redirect to admin dashboard (route defined in Phase 4)
        {:halt, redirect(socket, to: "/admin")}

      _ ->
        {:halt, redirect(socket, to: ~p"/admin/log-in")}
    end
  end

  # PRIVATE

  defp assign_current_scope(socket, session) do
    scope =
      case session["user_token"] && Accounts.get_user_by_session_token(session["user_token"]) do
        {user, _token_inserted_at} -> Scope.for_user(user)
        _ -> nil
      end

    assign(socket, :current_scope, scope)
  end
end
