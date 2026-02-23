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

  # Public routes — no authentication required.
  # PageController handles the / → /eq redirect (plain controller, no live_session needed).
  # AuxiliaryLive handles each auxiliary's public landing page.
  scope "/", SeventhWardEqWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :public do
      live "/:slug", AuxiliaryLive
    end
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
