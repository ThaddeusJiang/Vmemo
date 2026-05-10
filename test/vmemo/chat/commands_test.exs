defmodule Vmemo.Chat.CommandsTest do
  use ExUnit.Case, async: true

  alias Vmemo.Chat.Commands

  describe "compact_summary/1" do
    test "returns fallback text for empty list" do
      assert Commands.compact_summary([]) == "No prior context to summarize."
    end

    test "normalizes source, trims text and joins lines" do
      messages = [
        %{source: :user, text: "  hello  "},
        %{source: "assistant", text: "world"}
      ]

      assert Commands.compact_summary(messages) == "USER: hello\nASSISTANT: world"
    end

    test "limits to latest 8 messages" do
      messages =
        for n <- 1..10 do
          %{source: :user, text: "m#{n}"}
        end

      summary = Commands.compact_summary(messages)
      lines = String.split(summary, "\n", trim: true)
      refute "USER: m1" in lines
      refute "USER: m2" in lines
      assert "USER: m10" in lines
    end

    test "truncates each line text to 300 chars" do
      long_text = String.duplicate("a", 320)
      summary = Commands.compact_summary([%{source: :user, text: long_text}])

      assert summary == "USER: " <> String.duplicate("a", 300)
    end

    test "handles nil text as empty string" do
      assert Commands.compact_summary([%{source: :assistant, text: nil}]) == "ASSISTANT: "
    end
  end
end
