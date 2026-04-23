import Config

# OpenRouter API Key for chat functionality
config :vmemo, openrouter_api_key: System.get_env("OPENROUTER_API_KEY")

config :vmemo,
  openrouter_chat_model: System.get_env("OPENROUTER_CHAT_MODEL", "openrouter:openai/gpt-4o-mini"),
  openrouter_vision_model:
    System.get_env("OPENROUTER_VISION_MODEL", "openrouter:google/gemma-4-26b-a4b-it")

config :req_llm,
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY")

if config_env() in [:dev, :test] do
  config :vmemo, Vmemo.Repo, url: System.fetch_env!("DATABASE_URL")

  config :vmemo,
    typesense_url: System.fetch_env!("TYPESENSE_URL"),
    typesense_api_key: System.get_env("TYPESENSE_API_KEY") || "xyz",
    moondream_url: System.fetch_env!("MOONDREAM_URL"),
    moondream_api_key: System.get_env("MOONDREAM_API_KEY") || "xyz"
end

if chunk_size = System.get_env("USER_DATA_IMPORT_TYPESENSE_CHUNK_SIZE") do
  case Integer.parse(chunk_size) do
    {value, ""} when value > 0 ->
      config :vmemo, user_data_import_typesense_chunk_size: value

    _ ->
      raise """
      environment variable USER_DATA_IMPORT_TYPESENSE_CHUNK_SIZE is invalid.
      It must be a positive integer.
      """
  end
end

if chunk_pause_ms = System.get_env("USER_DATA_IMPORT_TYPESENSE_CHUNK_PAUSE_MS") do
  case Integer.parse(chunk_pause_ms) do
    {value, ""} when value >= 0 ->
      config :vmemo, user_data_import_typesense_chunk_pause_ms: value

    _ ->
      raise """
      environment variable USER_DATA_IMPORT_TYPESENSE_CHUNK_PAUSE_MS is invalid.
      It must be a non-negative integer.
      """
  end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Enable Phoenix server in prod (e.g. set PHX_SERVER=true in Docker).
if System.get_env("PHX_SERVER") do
  config :vmemo, VmemoWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: postgres://USER:PASS@HOST/DATABASE
      """

  admin_token =
    System.get_env("ADMIN_TOKEN") ||
      raise """
      environment variable ADMIN_TOKEN is missing.
      Please set a secure admin token for production.
      """

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  resend_api_key =
    System.get_env("RESEND_API_KEY") ||
      raise """
      environment variable RESEND_API_KEY is missing.
      """

  typesense_url =
    System.get_env("TYPESENSE_URL") ||
      raise """
      environment variable TYPESENSE_URL is missing.
      """

  typesense_api_key =
    System.get_env("TYPESENSE_API_KEY") ||
      raise """
      environment variable TYPESENSE_API_KEY is missing.
      """

  moondream_url =
    System.get_env("MOONDREAM_URL") ||
      raise """
      environment variable MOONDREAM_URL is missing.
      """

  moondream_api_key =
    System.get_env("MOONDREAM_API_KEY") ||
      raise """
      environment variable MOONDREAM_API_KEY is missing.
      """

  openrouter_api_key =
    System.get_env("OPENROUTER_API_KEY") ||
      raise """
      environment variable OPENROUTER_API_KEY is missing.
      """

  sentry_dsn =
    System.get_env("SENTRY_DSN") ||
      raise """
      environment variable SENTRY_DSN is missing.
      """

  config :vmemo,
    typesense_url: typesense_url,
    typesense_api_key: typesense_api_key,
    moondream_url: moondream_url,
    moondream_api_key: moondream_api_key,
    openrouter_api_key: openrouter_api_key

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :vmemo, Vmemo.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :vmemo, admin_token: admin_token

  config :vmemo, Oban,
    repo: Vmemo.Repo,
    plugins: [Oban.Plugins.Pruner],
    queues: [
      default: 10,
      chat_responses: 10,
      conversations: 10,
      sync_typesense: 10,
      ai_vision: 10,
      import_requests: 10
    ]

  config :sentry,
    dsn: sentry_dsn,
    environment_name: System.get_env("SENTRY_ENV") || "prod",
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()]

  host = System.get_env("PHX_HOST") || "vmemo.app"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :vmemo, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Store secret_key_base in application config for JWT signing
  # JWT_SIGNING_SECRET is now merged with SECRET_KEY_BASE
  config :vmemo, :secret_key_base, secret_key_base

  config :vmemo, VmemoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :vmemo, VmemoWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :vmemo, VmemoWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  config :vmemo, Vmemo.Mailer,
    adapter: Resend.Swoosh.Adapter,
    api_key: resend_api_key

  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
