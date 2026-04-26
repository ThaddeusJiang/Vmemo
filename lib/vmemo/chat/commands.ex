defmodule Vmemo.Chat.Commands do
  @moduledoc false

  def parse(text) when is_binary(text) do
    case String.trim(text) do
      "/clear" -> {:ok, :clear}
      "/compact" -> {:ok, :compact}
      _ -> :no_command
    end
  end

  def parse(_), do: :no_command

  def compact_summary(messages) when is_list(messages) do
    messages
    |> Enum.take(-8)
    |> Enum.map(fn message ->
      source = message.source |> to_string() |> String.upcase()
      text = (message.text || "") |> String.trim() |> String.slice(0, 300)
      "#{source}: #{text}"
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> case do
      "" -> "No prior context to summarize."
      text -> text
    end
  end
end
