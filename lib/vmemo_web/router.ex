defmodule VmemoWeb.Router do
  use VmemoWeb, :router

  import VmemoWeb.AshUserAuth
  import VmemoWeb.AdminAuth
  import AshAdmin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VmemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_ash_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug VmemoWeb.ApiAuth
  end

  # MCP pipeline - optional authentication for MCP server
  # Allows unauthenticated access for public tools, but sets actor if API token is provided
  # Only supports StreamableHttp (POST requests), not SSE (GET requests)
  pipeline :mcp do
    plug :accepts, ["json", "event-stream"]
    plug VmemoWeb.McpAuth
  end

  scope "/", VmemoWeb do
    pipe_through :browser

    get "/", PageController, :landing
  end

  # API routes
  scope "/api/v1", VmemoWeb.Api.V1 do
    pipe_through [:api, :api_auth]

    post "/photos", PhotoController, :create
    get "/photos/:id", PhotoController, :show
    delete "/photos/:id", PhotoController, :delete
  end

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
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/dev", VmemoWeb do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VmemoWeb.Telemetry
      oban_dashboard("/oban")

      live_session :dev_ui,
        on_mount: [{VmemoWeb.AshUserAuth, :mount_current_ash_user}] do
        live "/ui", Live.UiPlayground
      end
    end
  end

  ## Authentication routes

  scope "/", VmemoWeb do
    pipe_through [:browser]

    # 注册和登录页面允许已登录用户访问（会显示提示信息）
    live_session :auth_pages,
      on_mount: [{VmemoWeb.AshUserAuth, :mount_current_ash_user}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserSessionLive, :new
    end

    post "/login", AshUserSessionController, :create
  end

  scope "/", VmemoWeb do
    pipe_through [:browser, :redirect_if_ash_user_is_authenticated]

    # 密码重置页面不允许已登录用户访问
    live_session :redirect_if_ash_user_is_authenticated,
      on_mount: [{VmemoWeb.AshUserAuth, :redirect_if_ash_user_is_authenticated}] do
      live "/reset-password", UserForgotPasswordLive, :new
      live "/reset-password/:token", UserResetPasswordLive, :edit
    end
  end

  scope "/", VmemoWeb do
    pipe_through [:browser, :require_authenticated_ash_user]

    live_session :require_authenticated_ash_user,
      on_mount: [{VmemoWeb.AshUserAuth, :ensure_authenticated_ash_user}] do
      live "/home", HomePageLive, :index
      live "/photos", PhotosIndexLive, :index
      live "/photos/upload", PhotoUploadLive
      live "/photos/:id", PhotoIdLive

      live "/notes/:id", NoteIdLive

      live "/settings", UserSettingsLive, :edit
      live "/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      # Chat routes
      live "/chat", ChatLive
      live "/chat/:conversation_id", ChatLive

      # API Token 管理路由
      live "/tokens", ApiTokenLive.Index, :index
      live "/tokens/new", ApiTokenLive.Form, :new
      live "/tokens/:id", ApiTokenLive.Show, :show
    end

    post "/users/update-password", AshUserSettingsController, :update
  end

  scope "/", VmemoWeb do
    pipe_through [:browser]

    delete "/users/logout", AshUserSessionController, :delete

    live_session :current_ash_user,
      on_mount: [{VmemoWeb.AshUserAuth, :mount_current_ash_user}] do
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

  # Production MCP Server routes
  # According to https://hexdocs.pm/ash_ai/readme.html
  # Note: MCP pipeline accepts both json and text/event-stream formats
  scope "/mcp" do
    pipe_through [:mcp]

    forward "/", AshAi.Mcp.Router,
      protocol_version_statement: "2024-11-05",
      otp_app: :vmemo
  end
end
