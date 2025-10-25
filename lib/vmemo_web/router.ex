defmodule VmemoWeb.Router do
  use VmemoWeb, :router

  import VmemoWeb.UserAuth
  import VmemoWeb.AdminAuth
  import AshAdmin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VmemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
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
    import Oban.Web.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VmemoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      oban_dashboard("/oban")
    end
  end

  ## Authentication routes

  scope "/", VmemoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{VmemoWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
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

      # API Token 管理路由
      live "/tokens", ApiTokenLive.Index, :index
      live "/tokens/new", ApiTokenLive.Form, :new
      live "/tokens/:id", ApiTokenLive.Show, :show

      live "/ui", Live.UiPlayground
    end
  end

  scope "/", VmemoWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{VmemoWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/storage/v1/", VmemoWeb do
    pipe_through :browser

    get "/:user_id/photos/:filename", FileController, :show
  end

  # Admin authentication routes
  scope "/admin" do
    pipe_through [:browser, :redirect_if_admin_is_authenticated]

    live_session :redirect_if_admin_is_authenticated,
      on_mount: [{VmemoWeb.AdminAuth, :redirect_if_admin_is_authenticated}] do
      live "/login", VmemoWeb.AdminLoginLive, :new
    end

    post "/login", VmemoWeb.AdminSessionController, :create
  end

  # Admin protected routes (require admin privileges)
  scope "/admin" do
    pipe_through [:browser, :require_admin_silent]

    ash_admin("/")

    delete "/logout", VmemoWeb.AdminSessionController, :delete
  end
end
