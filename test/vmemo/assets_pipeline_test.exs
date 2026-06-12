defmodule Vmemo.AssetsPipelineTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  test "frontend dependencies are managed by the assets npm manifest" do
    package_json =
      @repo_root
      |> Path.join("assets/package.json")
      |> File.read!()
      |> Jason.decode!()

    dependencies = package_json["dependencies"] || %{}
    dev_dependencies = package_json["devDependencies"] || %{}
    all_dependencies = Map.merge(dependencies, dev_dependencies)

    assert package_json["private"] == true
    assert package_json["scripts"]["setup"] == "npm ci"
    assert package_json["scripts"]["build"] == "npm run build:css"
    assert package_json["scripts"]["deploy"] == "npm run deploy:css"
    refute Map.has_key?(package_json["scripts"], "build:js")
    refute Map.has_key?(package_json["scripts"], "deploy:js")
    refute Map.has_key?(package_json["scripts"], "watch:js")

    assert all_dependencies["tailwindcss"] == "4.3.0"
    assert all_dependencies["@tailwindcss/cli"] == "4.3.0"
    assert all_dependencies["daisyui"] == "5.5.23"
    assert all_dependencies["heroicons"] == "2.2.0"
    assert all_dependencies["choices.js"] == "11.2.3"

    refute Map.has_key?(all_dependencies, "esbuild")
    refute Map.has_key?(all_dependencies, "phoenix")
    refute Map.has_key?(all_dependencies, "phoenix_html")
    refute Map.has_key?(all_dependencies, "phoenix_live_view")

    refute File.exists?(Path.join(@repo_root, "assets/vendor"))
  end

  test "mix asset aliases use npm for CSS packages and Hex esbuild for JavaScript" do
    mix_exs = File.read!(Path.join(@repo_root, "mix.exs"))

    assert mix_exs =~ ~s|{:esbuild, "~> 0.8", runtime: Mix.env() == :dev}|

    assert mix_exs =~
             ~s("assets.setup": ["cmd npm ci --prefix assets", "esbuild.install --if-missing"])

    assert mix_exs =~ ~s("assets.build": ["cmd npm run build --prefix assets", "esbuild vmemo"])

    assert mix_exs =~
             ~r/"assets\.deploy": \[\s*"cmd npm run deploy --prefix assets",\s*"esbuild vmemo --minify",\s*"phx\.digest"\s*\]/

    refute mix_exs =~ "{:tailwind,"
    refute mix_exs =~ "{:heroicons,"
    refute mix_exs =~ "tailwind.install"
    refute mix_exs =~ "tailwind vmemo"
  end

  test "development watchers run npm CSS and Hex esbuild" do
    dev_exs = File.read!(Path.join(@repo_root, "config/dev.exs"))

    assert dev_exs =~ ~s(npm: ["run", "watch:css", "--prefix", "assets"])

    assert dev_exs =~
             ~s|esbuild: {Esbuild, :install_and_run, [:vmemo, ~w(--sourcemap=inline --watch)]}|

    refute dev_exs =~ "npm_css:"
  end

  test "asset source files import npm packages instead of vendored files" do
    asset_sources =
      @repo_root
      |> Path.join("assets/**/*.{css,js}")
      |> Path.wildcard()
      |> Enum.reject(&String.contains?(&1, "/node_modules/"))

    assert asset_sources != []

    for path <- asset_sources do
      source = File.read!(path)

      refute source =~ "../vendor",
             "#{Path.relative_to(path, @repo_root)} still imports from assets/vendor"

      refute source =~ "../../vendor",
             "#{Path.relative_to(path, @repo_root)} still imports from assets/vendor"
    end
  end
end
