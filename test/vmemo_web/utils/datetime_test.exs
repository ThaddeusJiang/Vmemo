defmodule VmemoWeb.Utils.DatetimeTest do
  use ExUnit.Case, async: true

  doctest VmemoWeb.Utils.Datetime

  alias VmemoWeb.Utils.Datetime

  test "format_datetime handles nil and iso string" do
    assert Datetime.format_datetime(nil) == "-"
    assert Datetime.format_datetime("2026-03-11T08:00:00Z") == "2026-03-11T08:00:00Z"
  end

  test "format_datetime handles naive and utc datetimes with second precision" do
    naive = ~N[2026-05-10 10:11:12.999]
    utc = DateTime.from_naive!(naive, "Etc/UTC")

    assert Datetime.format_datetime(naive) == "2026-05-10T10:11:12"
    assert Datetime.format_datetime(utc) == "2026-05-10T10:11:12Z"
  end

  test "format_datetime_human handles nil, invalid iso, valid iso, naive and utc" do
    naive = ~N[2026-05-10 10:11:12.999]
    utc = DateTime.from_naive!(naive, "Etc/UTC")

    assert Datetime.format_datetime_human(nil) == "-"
    assert Datetime.format_datetime_human("not-iso") == "not-iso"
    assert Datetime.format_datetime_human("2026-05-10T10:11:12Z") == "2026-05-10 10:11"
    assert Datetime.format_datetime_human(naive) == "2026-05-10 10:11"
    assert Datetime.format_datetime_human(utc) == "2026-05-10 10:11"
  end

  test "now_iso_datetime uses configured timezone and returns iso8601" do
    original_tz = Application.get_env(:vmemo, :time_zone)
    Application.put_env(:vmemo, :time_zone, "Etc/UTC")

    on_exit(fn ->
      if original_tz do
        Application.put_env(:vmemo, :time_zone, original_tz)
      else
        Application.delete_env(:vmemo, :time_zone)
      end
    end)

    now = Datetime.now_iso_datetime()
    assert {:ok, _dt, 0} = DateTime.from_iso8601(now)
  end
end
