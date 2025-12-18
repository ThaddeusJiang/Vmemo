defmodule Vmemo.Chat.OpenRouterChatModel do
  @moduledoc """
  OpenRouter ChatModel configuration for ash_ai chat feature.

  Uses OpenRouter API with openai/chatgpt-4o-latest model.
  """
  alias LangChain.ChatModels.ChatOpenAI

  @doc """
  Creates a new ChatOpenAI instance configured for OpenRouter.

  Requires OPENROUTER_API_KEY environment variable (configured in config/runtime.exs).
  """
  def new(opts \\ []) do
    api_key = Application.get_env(:vmemo, :openrouter_api_key)

    if is_nil(api_key) or api_key == "" do
      raise "OPENROUTER_API_KEY environment variable is required. Set it in config/runtime.exs."
    end

    ChatOpenAI.new(%{
      endpoint: "https://openrouter.ai/api/v1/chat/completions",
      model: "openai/chatgpt-4o-latest",
      api_key: api_key,
      stream: Keyword.get(opts, :stream, true),
      temperature: Keyword.get(opts, :temperature, 1.0)
    })
  end

  @doc """
  Creates a new ChatOpenAI instance with error handling.
  """
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, chat} -> chat
      {:error, reason} -> raise "Failed to create OpenRouter chat model: #{inspect(reason)}"
      chat -> chat
    end
  end
end
