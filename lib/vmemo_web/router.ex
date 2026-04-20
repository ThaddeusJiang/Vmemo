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

    post "/images", ImageController, :create
    get "/images/:id", ImageController, :show
    delete "/images/:id", ImageController, :delete
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

      live_dashboard "/dashboard",
        metrics: VmemoWeb.Telemetry,
        additional_pages: [
          external_services: VmemoWeb.LiveDashboard.ExternalServicesPage
        ]

      oban_dashboard("/oban")

      live_session :dev_ui,
        on_mount: [{VmemoWeb.UserAuth, :mount_current_user}] do
        live "/ui", Live.UiPlayground
      end
    end
  end

  ## Authentication routes

  scope "/", VmemoWeb do
    pipe_through [:browser]

    # Registration and sign-in pages allow authenticated users (with a notice)
    live_session :auth_pages,
      on_mount: [{VmemoWeb.UserAuth, :mount_current_user}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserSessionLive, :new
    end

    post "/login", UserSessionController, :create
  end

  scope "/", VmemoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    # Password reset pages do not allow authenticated users
    live_session :redirect_if_user_is_authenticated,
      on_mount: [{VmemoWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/reset-password", UserForgotPasswordLive, :new
      live "/reset-password/:token", UserResetPasswordLive, :edit
    end
  end

  scope "/", VmemoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {VmemoWeb.UserAuth, :ensure_authenticated_user},
        {VmemoWeb.Live.ImageJobsHook, :default}
      ] do
      live "/home", HomePageLive, :index
      live "/images", ImagesIndexLive, :index
      live "/images/upload", ImageUploadLive
      live "/images/:id", ImageIdLive
      live "/jobs", JobsLive, :index

      live "/notes/:id", NoteIdLive

      live "/settings", UserSettingsLive, :edit
      live "/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      # Chat routes
      live "/chat", ChatLive
      live "/chat/:conversation_id", ChatLive

      # API Token management routes
      live "/tokens", ApiTokenLive.Index, :index
      live "/tokens/new", ApiTokenLive.Form, :new
      live "/tokens/:id", ApiTokenLive.Show, :show
    end

    get "/settings/export", UserDataController, :export
    post "/users/update-password", UserSettingsController, :update
  end

  scope "/", VmemoWeb do
    pipe_through [:browser]

    delete "/users/logout", UserSessionController, :delete
    get "/users/confirm-login/:token", UserConfirmationController, :confirm

    live_session :current_user,
      on_mount: [{VmemoWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/storage/v1/", VmemoWeb do
    pipe_through :browser

    get "/:user_id/images/:filename", FileController, :show
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

    live_session :admin,
      on_mount: [{VmemoWeb.AdminAuth, :ensure_admin}] do
      live "/import", VmemoWeb.AdminImportLive, :index
    end

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
