defmodule Vmemo.Ai.VisionConfig do
  @moduledoc false

  def resolve(_user_id \\ nil) do
    %{
      api_key: Application.get_env(:vmemo, :openrouter_api_key),
      model: normalize_model(Application.fetch_env!(:vmemo, :openrouter_vision_model))
    }
  end

  defp normalize_model(model) when is_binary(model) do
    if String.contains?(model, ":") do
      model
    else
      "openrouter:" <> model
    end
  end
end
