defmodule VmemoWeb.Utils.Datetime do
  @moduledoc """
  Datetime helpers for Web UI and APIs.
  """

  @doc """
  Format a datetime value into an ISO8601 string.

  Accepts `nil`, an ISO8601 string, `NaiveDateTime`, or `DateTime`.

  ## Examples

      iex> VmemoWeb.Utils.Datetime.format_datetime(nil)
      "-"

      iex> VmemoWeb.Utils.Datetime.format_datetime("2026-03-11T08:00:00Z")
      "2026-03-11T08:00:00Z"
  """
  def format_datetime(nil), do: "-"

  def format_datetime(iso) when is_binary(iso), do: iso

  def format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
  end

  def format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  @doc """
  Format a datetime value into a human-readable string for UI.

  Output format: `"YYYY-MM-DD HH:mm"` in the configured time zone.

  Accepts `nil`, an ISO8601 string, `NaiveDateTime`, or `DateTime`.

  ## Examples

      iex> VmemoWeb.Utils.Datetime.format_datetime_human(nil)
      "-"

      iex> VmemoWeb.Utils.Datetime.format_datetime_human("2026-03-11T08:00:00Z") |> String.length()
      16
  """
  def format_datetime_human(nil), do: "-"

  def format_datetime_human(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> format_datetime_human(dt)
      _ -> iso
    end
  end

  def format_datetime_human(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  def format_datetime_human(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  @doc """
  Return the current time in the configured time zone as an ISO8601 string.

  The time zone is read from `:vmemo, :time_zone` (defaults to `"Etc/UTC"`).

  ## Examples

      iex> is_binary(VmemoWeb.Utils.Datetime.now_iso_datetime())
      true
  """
  def now_iso_datetime do
    time_zone = Application.get_env(:vmemo, :time_zone, "Etc/UTC")

    time_zone
    |> DateTime.now!()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
