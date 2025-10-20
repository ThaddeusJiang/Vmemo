defmodule VmemoWeb.Router do
  use VmemoWeb, :router
  use AshAuthentication.Phoenix.Router

  import VmemoWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VmemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VmemoWeb do
    pipe_through :browser

    get "/", PageController, :landing
  end

  # Other scopes may use custom stacks.
  # scope "/api", VmemoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:vmemo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VmemoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", VmemoWeb do
    pipe_through :browser

    sign_in_route(
      register_path: "/register",
      reset_path: "/reset",
      auth_routes_prefix: "/auth",
      on_mount: [{VmemoWeb.UserAuth, :mount_current_user}],
      overrides: [AshAuthentication.Phoenix.Overrides.Default, VmemoWeb]
    )

    sign_out_route AuthController
    auth_routes AuthController, Vmemo.Account.Resources.User, path: "/auth"
    reset_route []
  end

  scope "/", VmemoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{VmemoWeb.UserAuth, :ensure_authenticated}] do
      live "/home", HomePageLive, :index
      live "/photos", HomePageLive, :index
      live "/photos/:id", PhotoIdLive
      # live "/home/upload", HomePageLive, :upload

      live "/notes/:id", NoteIdLive

      live "/upload", PhotoUploadLive

      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      live "/ui", Live.UiPlayground
    end
  end


  scope "/storage/v1/", VmemoWeb do
    pipe_through :browser

    get "/:user_id/photos/:filename", FileController, :show
  end
end
