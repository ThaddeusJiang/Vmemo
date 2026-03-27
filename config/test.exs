import Config

config :ash, policies: [show_policy_breakdowns?: true]

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :vmemo, Vmemo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("POSTGRES_PORT", "54321")),
  database: "vmemo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :vmemo, typesense_url: System.get_env("TYPESENSE_URL", "http://localhost:8766")
config :vmemo, typesense_api_key: System.get_env("TYPESENSE_API_KEY", "xyz")
config :vmemo, typesense_image_embedding: false

config :vmemo, moondream_url: "http://localhost:2020/v1"

# Admin token for test
config :vmemo, admin_token: "admin"

config :vmemo, Oban,
  repo: Vmemo.Repo,
  testing: :inline

# Store secret_key_base in application config for JWT signing
# JWT_SIGNING_SECRET is now merged with SECRET_KEY_BASE
config :vmemo,
       :secret_key_base,
       "qcL8bHOhBq7jlQEGhUr0/fY2FJCoMWQZ/lfGYLr03lgXzx8bWSaBis3Zhx0ISBe7"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :vmemo, VmemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qcL8bHOhBq7jlQEGhUr0/fY2FJCoMWQZ/lfGYLr03lgXzx8bWSaBis3Zhx0ISBe7",
  server: false

# In test we don't send emails
config :vmemo, Vmemo.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
