defmodule Vmemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :vmemo,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: Mix.compilers() ++ [],
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Vmemo.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:mdex, "~> 0.7"},
      {:ash_ai, "~> 0.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.20"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.19.9"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:resend, "~> 0.4"},
      {:req, "~> 0.5.10"},
      {:mime, "~> 2.0"},
      {:tidewave, "~> 0.5", only: :dev},
      {:sourceror, "~> 1.7"},
      {:ash, "~> 3.0"},
      {:ash_postgres, ">= 2.6.8"},
      {:ash_phoenix, "~> 2.1"},
      {:ash_oban, "~> 0.2"},
      {:ash_admin, "~> 0.13.19"},
      {:ash_authentication, "~> 4.13"},
      {:oban, "~> 2.19"},
      {:oban_web, "~> 2.0"},
      {:sentry, "~> 11.0"},
      {:hackney, "~> 1.21"},
      {:igniter, "~> 0.7"},
      {:open_api_spex, "~> 3.22"},
      {:oban_met, "~> 1.0"},
      {:owl, "~> 0.13"},
      {:spark, "~> 2.3"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "ts.reset", "assets.setup", "assets.build"],
      clean: ["clean.all"],
      reset: ["ash.reset", "ts.reset", "storage.reset"],
      "ash.setup": ["ash_postgres.create", "ash.migrate", "run priv/repo/seeds.exs"],
      "ash.reset": ["ash_postgres.drop", "ash.setup"],
      test: ["ash_postgres.create --quiet", "ash.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind vmemo", "esbuild vmemo"],
      "assets.deploy": [
        "tailwind vmemo --minify",
        "esbuild vmemo --minify",
        "phx.digest"
      ]
    ]
  end
end
