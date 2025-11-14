[
  import_deps: [
    :ecto,
    :ecto_sql,
    :phoenix,
    :ash,
    :reactor,
    :ash_phoenix,
    :ash_postgres,
    :ash_oban
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter, Spark.Formatter],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "_local/*.{ex,exs}"
  ]
]
