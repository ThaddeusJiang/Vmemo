defmodule Vmemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :vmemo,
      version: "2026.4.29",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: dialyzer(),
      docs: &docs/0,
      compilers: Mix.compilers() ++ [],
      gettext: [
        write_reference_line_numbers: false
      ],
      usage_rules: usage_rules()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test
      ]
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
      {:ash_ai, "~> 0.6.1"},
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
      {:usage_rules, "~> 1.2", only: [:dev]},
      {:open_api_spex, "~> 3.22"},
      {:oban_met, "~> 1.0"},
      {:owl, "~> 0.13"},
      {:spark, "~> 2.3"},
      {:mock, "~> 0.3.9", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/project.plt"},
      plt_add_deps: :app_tree,
      plt_add_apps: [:mix]
    ]
  end

  defp docs do
    resource_diagram_extras =
      Path.wildcard("lib/vmemo/*-mermaid-class-diagram.md")
      |> Enum.sort()

    [
      main: "home",
      api_reference: false,
      before_closing_body_tag: &before_closing_body_tag/1,
      extras:
        [
          {"README.md", [filename: "home", title: "Home"]},
          {"docs/features/api-tokens.md", [title: "API Token (REST API Preparation)"]},
          {"docs/features/public-rest-api.md", [title: "REST API"]},
          {"docs/features/mcp-server.md", [title: "MCP Server"]},
          {"docs/guides/development/setup.md", [title: "Development"]},
          "docs/guides/deployment/docker.md"
        ] ++ resource_diagram_extras
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";

      const hideDiagramMenuItems = () => {
        const selector = '#sidebar a[href$="-mermaid-class-diagram.html"]';
        for (const linkEl of document.querySelectorAll(selector)) {
          const itemEl = linkEl.closest("li");
          if (itemEl) {
            itemEl.remove();
          }
        }
      };

      hideDiagramMenuItems();
      window.addEventListener("exdoc:loaded", hideDiagramMenuItems);

      mermaid.initialize({startOnLoad: false});
      let id = 0;
      for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
        const preEl = codeEl.parentElement;
        const graphDefinition = codeEl.textContent;
        const graphEl = document.createElement("div");
        const graphId = `mermaid-graph-${id++}`;
        mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
          graphEl.innerHTML = svg;
          bindFunctions?.(graphEl);
          preEl.insertAdjacentElement("afterend", graphEl);
          preEl.remove();
        });
      }
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [
        {:phoenix, link: :markdown},
        {:ash, link: :markdown}
      ],
      skills: [
        location: ".codex/skills",
        build: [
          "ash-framework": [
            description:
              "Use this skill when working with Ash Framework and its extensions. Consult before domain modeling, resources, actions, and data-layer changes.",
            usage_rules: [:ash, ~r/^ash_/]
          ],
          "phoenix-framework": [
            description:
              "Use this skill when working with Phoenix and LiveView web layers, routing, rendering, templates, and events.",
            usage_rules: [:phoenix, ~r/^phoenix_/]
          ]
        ]
      ]
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
      setup: ["deps.get", "db.setup", "ts.setup", "assets.setup", "assets.build"],
      reset: ["db.reset", "ts.reset"],
      "db.create": ["ash_postgres.create"],
      "db.drop": ["ash_postgres.drop"],
      "db.migrate": ["ash.migrate"],
      "db.rollback": ["ash_postgres.rollback"],
      "db.seed": ["run priv/repo/seeds.exs"],
      "db.setup": ["db.create", "db.migrate", "db.seed"],
      "db.reset": ["db.drop", "db.setup"],
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "gettext.extract --check-up-to-date",
        "xref graph --format cycles --label compile --fail-above 0",
        "credo --strict",
        "sobelow --config",
        "hex.audit",
        "deps.unlock --check-unused",
        "dialyzer --format short"
      ],
      "ts.setup": ["ts.migrate"],
      "ts.reset": ["ts.drop", "ts.setup"],
      test: ["ash_postgres.create --quiet", "ash.migrate --quiet", "ts.migrate", "test"],
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
