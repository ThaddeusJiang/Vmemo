defmodule Vmemo.ImportExport.HelpersTest do
  use ExUnit.Case, async: true

  alias Vmemo.ImportExport.Errors
  alias Vmemo.ImportExport.Ids

  describe "Ids.normalize_record_id/1" do
    test "returns uuid tuple for valid uuid" do
      id = Ecto.UUID.generate()
      assert Ids.normalize_record_id(id) == {:uuid, id}
    end

    test "returns legacy tuple for integer" do
      assert Ids.normalize_record_id(123) == {:legacy, 123}
    end

    test "returns invalid for unsupported input" do
      assert Ids.normalize_record_id("not-a-uuid") == :invalid
      assert Ids.normalize_record_id(nil) == :invalid
    end
  end

  describe "Ids.valid_uuid?/1" do
    test "validates uuid binary and rejects non-binary" do
      assert Ids.valid_uuid?(Ecto.UUID.generate())
      refute Ids.valid_uuid?("invalid")
      refute Ids.valid_uuid?(123)
    end
  end

  describe "Errors helpers" do
    test "append_errors/2 appends list and ignores non-list" do
      assert Errors.append_errors(["a"], ["b", "c"]) == ["a", "b", "c"]
      assert Errors.append_errors(["a"], :oops) == ["a"]
    end

    test "add_error/3 respects limit" do
      assert Errors.add_error(["a", "b"], "c", 2) == ["a", "b"]
      assert Errors.add_error(["a"], "b", 2) == ["a", "b"]
    end

    test "format_error/1 keeps binaries and inspects others" do
      assert Errors.format_error("plain") == "plain"
      assert Errors.format_error(%{k: :v}) == "%{k: :v}"
    end
  end
end
