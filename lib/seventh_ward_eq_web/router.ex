defmodule SeventhWardEqWeb.Router do
  use SeventhWardEqWeb, :router

  import SeventhWardEqWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SeventhWardEqWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public home route — redirect / → /eq.
  scope "/", SeventhWardEqWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", SeventhWardEqWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:seventh_ward_eq, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SeventhWardEqWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Admin portal routes
  #
  # All admin LiveViews live under /admin. Two live_sessions:
  #   :admin_required  — content management (admins + superadmin)
  #   :superadmin_required — user management (superadmin only)
  #
  # These must be defined BEFORE the public /:slug catch-all route below.
  scope "/admin", SeventhWardEqWeb do
    pipe_through :browser

    live_session :admin_required,
      on_mount: {SeventhWardEqWeb.LiveHooks.Auth, :require_admin} do
      live "/", Admin.DashboardLive
      live "/posts", Admin.PostLive, :index
      live "/posts/new", Admin.PostLive, :new
      live "/posts/:id/edit", Admin.PostLive, :edit
      live "/events", Admin.EventLive, :index
      live "/events/new", Admin.EventLive, :new
      live "/events/:id/edit", Admin.EventLive, :edit
    end

    live_session :superadmin_required,
      on_mount: {SeventhWardEqWeb.LiveHooks.Auth, :require_superadmin} do
      live "/users", Admin.UserLive, :index
      live "/users/new", Admin.UserLive, :new
    end
  end

  # Public slug routes — must come AFTER all static /admin routes so the
  # /:slug catch-all does not swallow admin paths.
  scope "/", SeventhWardEqWeb do
    pipe_through :browser

    live_session :public do
      live "/:slug", AuxiliaryLive
    end
  end

  ## Authentication routes

  scope "/", SeventhWardEqWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/admin/settings", UserSettingsController, :edit
    put "/admin/settings", UserSettingsController, :update
    get "/admin/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", SeventhWardEqWeb do
    pipe_through [:browser]

    get "/admin/log-in", UserSessionController, :new
    get "/admin/log-in/:token", UserSessionController, :confirm
    post "/admin/log-in", UserSessionController, :create
    delete "/admin/log-out", UserSessionController, :delete
  end
end
