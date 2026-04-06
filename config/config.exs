# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :vmemo, Oban,
  queues: [
    default: [limit: 10],
    chat_responses: [limit: 10],
    conversations: [limit: 10],
    sync_typesense: [limit: 10],
    ai_vision: [limit: 10],
    import_requests: [limit: 10]
  ]

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true

config :spark,
  formatter: [
    remove_parens?: false,
    "Ash.Resource": [
      section_order: [
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [section_order: [:resources, :policies, :authorization, :domain, :execution]]
  ]

config :vmemo,
  ecto_repos: [Vmemo.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Vmemo.Chat, Vmemo.Memo, Vmemo.Ai, Vmemo.AccountDomain, Vmemo.Admin],
  user_data_import_typesense_chunk_size: 50,
  user_data_import_typesense_chunk_pause_ms: 50

config :vmemo, :ash_domains, [
  Vmemo.Chat,
  Vmemo.Memo,
  Vmemo.Ai,
  Vmemo.AccountDomain,
  Vmemo.Admin
]

# Configures the endpoint
config :vmemo, VmemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: VmemoWeb.ErrorHTML, json: VmemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Vmemo.PubSub,
  live_view: [signing_salt: "8/KymdRN"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :vmemo, Vmemo.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  vmemo: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  vmemo: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Register text/event-stream MIME type for MCP server SSE support
config :mime, :types, %{
  "text/event-stream" => ["event-stream"]
}

# Disable Tesla deprecation warning
# Tesla is a transitive dependency via resend, and we don't use it directly
config :tesla, disable_deprecated_builder_warning: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
