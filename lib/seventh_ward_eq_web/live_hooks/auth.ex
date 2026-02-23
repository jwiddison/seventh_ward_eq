defmodule SeventhWardEqWeb.LiveHooks.Auth do
  @moduledoc """
  LiveView `on_mount` hooks for admin portal authentication.

  All admin routes are LiveView-based, so authentication is enforced here
  via `on_mount` hooks wired into `live_session` blocks in the router.
  There are no controller plugs for the admin portal.

  Usage in the router:

      live_session :admin_required,
        on_mount: {SeventhWardEqWeb.LiveHooks.Auth, :require_admin} do
        live "/admin", Admin.DashboardLive
      end

  """

  use SeventhWardEqWeb, :verified_routes

  import Phoenix.LiveView
  import Phoenix.Component

  alias SeventhWardEq.Accounts
  alias SeventhWardEq.Accounts.Scope

  @doc """
  Dispatcher for `live_session on_mount:` callbacks.

  Phoenix calls `on_mount(atom, params, session, socket)` where the atom is
  the second element of the `{Module, atom}` tuple in the router.

  Supported atoms:
  - `:require_admin` — allows admins and superadmins
  - `:require_superadmin` — allows superadmin only
  """
  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:require_admin, _params, session, socket) do
    socket = assign_current_scope(socket, session)

    case socket.assigns.current_scope do
      %{user: %{role: role}} when role in ["admin", "superadmin"] ->
        {:cont, socket}

      _ ->
        {:halt, redirect(socket, to: ~p"/admin/log-in")}
    end
  end

  def on_mount(:require_superadmin, _params, session, socket) do
    socket = assign_current_scope(socket, session)

    case socket.assigns.current_scope do
      %{user: %{role: "superadmin"}} ->
        {:cont, socket}

      %{user: %{}} ->
        {:halt, redirect(socket, to: ~p"/admin")}

      _ ->
        {:halt, redirect(socket, to: ~p"/admin/log-in")}
    end
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  @spec assign_current_scope(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_current_scope(socket, session) do
    scope =
      case session["user_token"] && Accounts.get_user_by_session_token(session["user_token"]) do
        {user, _token_inserted_at} -> Scope.for_user(user)
        _ -> nil
      end

    assign(socket, :current_scope, scope)
  end
end
