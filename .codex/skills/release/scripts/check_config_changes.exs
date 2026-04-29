defmodule Release.CheckConfigChanges do
  @moduledoc false

  @calver_regex ~r/^[0-9]{4}\.(1[0-2]|[1-9])\.([1-9][0-9]*)$/
  @env_regex ~r/\b[A-Z][A-Z0-9_]{2,}\b/

  @config_path_prefixes [
    "config/",
    "rel/",
    "priv/repo/",
    "priv/ts/"
  ]

  @config_path_exact [
    ".env",
    ".env.example",
    "Dockerfile",
    "docker-compose.yml",
    "mise.toml",
    ".github/workflows/publish-docker-image.yml"
  ]

  @env_scan_files [
    ".env.example",
    "config/runtime.exs",
    "config/dev.exs",
    "config/prod.exs",
    "config/test.exs"
  ]

  def main(args) do
    with {:ok, base} <- resolve_base(args),
         {:ok, target} <- resolve_target(args),
         :ok <- assert_ref(base),
         :ok <- assert_ref(target),
         {:ok, changed_files} <- changed_files(base, target) do
      report(base, target, changed_files)
    else
      {:error, reason} ->
        IO.puts(:stderr, reason)
        System.halt(1)
    end
  end

  defp resolve_base([base | _]), do: {:ok, normalize_ref(base)}

  defp resolve_base(_) do
    case latest_calver_tag() do
      {:ok, tag} -> {:ok, tag}
      :none -> fallback_base()
    end
  end

  defp resolve_target([_base, target | _]), do: {:ok, normalize_ref(target)}
  defp resolve_target(_), do: {:ok, "HEAD"}

  defp normalize_ref(ref), do: String.trim(ref)

  defp latest_calver_tag do
    with {:ok, output} <- run_git(["tag", "--list"]),
         tags <-
           output
           |> String.split("\n", trim: true)
           |> Enum.filter(&String.match?(&1, @calver_regex))
           |> Enum.map(&{&1, parse_calver(&1)})
           |> Enum.sort_by(fn {_tag, tuple} -> tuple end, :desc) do
      case tags do
        [{tag, _} | _] -> {:ok, tag}
        [] -> :none
      end
    end
  end

  defp parse_calver(version) do
    [y, m, p] = version |> String.split(".") |> Enum.map(&String.to_integer/1)
    {y, m, p}
  end

  defp fallback_base do
    cond do
      ref_exists?("origin/main") ->
        {:ok, "origin/main"}

      ref_exists?("origin/master") ->
        {:ok, "origin/master"}

      true ->
        {:error,
         "Cannot determine BASE_REF (no calver tag and no origin/main or origin/master)."}
    end
  end

  defp ref_exists?(ref) do
    case System.cmd("git", ["rev-parse", "--verify", "--quiet", ref], stderr_to_stdout: true) do
      {_out, 0} -> true
      _ -> false
    end
  end

  defp assert_ref(ref) do
    if ref_exists?(ref) do
      :ok
    else
      {:error, "Git ref does not exist: #{ref}"}
    end
  end

  defp changed_files(base, target) do
    run_git(["diff", "--name-only", "#{base}..#{target}"])
    |> case do
      {:ok, output} -> {:ok, String.split(output, "\n", trim: true)}
      other -> other
    end
  end

  defp report(base, target, changed_files) do
    config_files = Enum.filter(changed_files, &config_path?/1)
    env_changes = detect_env_changes(base, target)
    has_config = config_files != []
    has_env = env_changes.added != [] or env_changes.removed != []
    detected = has_config or has_env

    IO.puts("# Release Config Change Report")
    IO.puts("base_ref=#{base}")
    IO.puts("target_ref=#{target}")
    IO.puts("config_changes_detected=#{detected}")
    IO.puts("")

    IO.puts("## Changed Files (#{length(changed_files)})")

    if changed_files == [] do
      IO.puts("- None")
    else
      Enum.each(changed_files, &IO.puts("- #{&1}"))
    end

    IO.puts("")
    IO.puts("## Config-related File Changes (#{length(config_files)})")

    if config_files == [] do
      IO.puts("- None")
    else
      Enum.each(config_files, &IO.puts("- #{&1}"))
    end

    IO.puts("")
    IO.puts("## Env Key Changes")

    IO.puts("### Added")

    if env_changes.added == [] do
      IO.puts("- None")
    else
      Enum.each(env_changes.added, &IO.puts("- #{&1}"))
    end

    IO.puts("### Removed")

    if env_changes.removed == [] do
      IO.puts("- None")
    else
      Enum.each(env_changes.removed, &IO.puts("- #{&1}"))
    end

    if detected do
      IO.puts("")

      IO.puts(
        "WARNING: Config or env changes detected. Explicit confirmation is required before release."
      )

      System.halt(2)
    end
  end

  defp config_path?(path) do
    path in @config_path_exact or Enum.any?(@config_path_prefixes, &String.starts_with?(path, &1))
  end

  defp detect_env_changes(base, target) do
    files = Enum.filter(@env_scan_files, &file_changed?(&1, base, target))

    {added, removed} =
      Enum.reduce(files, {MapSet.new(), MapSet.new()}, fn file, {add_acc, rm_acc} ->
        case run_git(["diff", "--unified=0", "#{base}..#{target}", "--", file]) do
          {:ok, diff} ->
            plus =
              diff
              |> String.split("\n", trim: true)
              |> Enum.filter(&String.starts_with?(&1, "+"))
              |> Enum.reject(&String.starts_with?(&1, "+++"))
              |> Enum.flat_map(&Regex.scan(@env_regex, &1))
              |> List.flatten()
              |> MapSet.new()

            minus =
              diff
              |> String.split("\n", trim: true)
              |> Enum.filter(&String.starts_with?(&1, "-"))
              |> Enum.reject(&String.starts_with?(&1, "---"))
              |> Enum.flat_map(&Regex.scan(@env_regex, &1))
              |> List.flatten()
              |> MapSet.new()

            {MapSet.union(add_acc, plus), MapSet.union(rm_acc, minus)}

          {:error, _} ->
            {add_acc, rm_acc}
        end
      end)

    %{
      added: added |> MapSet.difference(removed) |> MapSet.to_list() |> Enum.sort(),
      removed: removed |> MapSet.difference(added) |> MapSet.to_list() |> Enum.sort()
    }
  end

  defp file_changed?(file, base, target) do
    case run_git(["diff", "--name-only", "#{base}..#{target}", "--", file]) do
      {:ok, ""} -> false
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp run_git(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim_trailing(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end
end

Release.CheckConfigChanges.main(System.argv())
