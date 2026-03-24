import Config

# OpenRouter API Key for chat functionality
config :vmemo, openrouter_api_key: System.get_env("OPENROUTER_API_KEY")

if url = System.get_env("TYPESENSE_URL") do
  config :vmemo, typesense_url: url
end

if api_key = System.get_env("TYPESENSE_API_KEY") do
  config :vmemo, typesense_api_key: api_key
end

# Moondream URL from env (overrides dev.exs / test.exs when set)
if url = System.get_env("MOONDREAM_URL") do
  config :vmemo, moondream_url: url
end

if api_key = System.get_env("MOONDREAM_API_KEY") do
  config :vmemo, moondream_api_key: api_key
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
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :vmemo, Vmemo.AshRepo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Admin password for production
  admin_token =
    System.get_env("ADMIN_PASSWORD") ||
      raise """
      environment variable ADMIN_PASSWORD is missing.
      Please set a secure admin password for production.
      """

  config :vmemo, admin_token: admin_token

  config :vmemo, Oban,
    repo: Vmemo.AshRepo,
    plugins: [Oban.Plugins.Pruner],
    queues: [default: 10, sync_typesense: 5]

  sentry_dsn =
    System.get_env("SENTRY_DSN") ||
      raise """
      environment variable SENTRY_DSN is missing.
      Please set a valid Sentry DSN for production.
      """

  config :sentry,
    dsn: sentry_dsn,
    environment_name: config_env(),
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

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
    api_key: System.fetch_env!("RESEND_API_KEY")

  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
