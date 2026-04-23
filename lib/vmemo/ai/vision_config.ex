defmodule Vmemo.Ai.VisionConfig do
  @moduledoc false

  @default_model "openai/gpt-4o-mini"

  def resolve(_user_id \\ nil) do
    %{
      api_key: Application.get_env(:vmemo, :openrouter_api_key),
      model: Application.get_env(:vmemo, :openrouter_vision_model) || @default_model
    }
  end
end
