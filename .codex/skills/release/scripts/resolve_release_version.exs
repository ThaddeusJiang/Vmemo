defmodule Release.ResolveVersion do
  @moduledoc false

  @version_regex ~r/^([0-9]{4})\.(1[0-2]|[1-9])\.([1-9][0-9]*)$/

  def main(args) do
    input = args |> List.first() |> normalize_blank()

    version =
      case input do
        nil ->
          default_version()

        value ->
          value
      end

    case validate(version) do
      :ok ->
        source = if input, do: "provided", else: "defaulted"
        IO.puts("release_version=#{version}")
        IO.puts("source=#{source}")

      {:error, reason} ->
        IO.puts(:stderr, reason)
        System.halt(1)
    end
  end

  defp normalize_blank(nil), do: nil

  defp normalize_blank(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp default_version do
    # Avoid requiring a timezone database in script-only execution.
    date = DateTime.utc_now() |> DateTime.add(9 * 60 * 60, :second) |> DateTime.to_date()
    "#{date.year}.#{date.month}.#{date.day}"
  end

  defp validate(version) do
    if String.match?(version, @version_regex) do
      :ok
    else
      {:error,
       "Invalid release version: #{inspect(version)}. Expected CalVer format YYYY.M.Patch with month 1..12 and patch >= 1."}
    end
  end
end

Release.ResolveVersion.main(System.argv())
