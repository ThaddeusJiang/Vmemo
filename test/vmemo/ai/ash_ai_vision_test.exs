defmodule Vmemo.Ai.AshAiVisionTest do
  use ExUnit.Case, async: false

  import Mock

  alias Vmemo.Ai.AshAiVision

  test "caption default prompt follows provided language" do
    with_mock ReqLLM.Message.ContentPart,
      text: fn prompt ->
        send(self(), {:prompt, prompt})
        {:text, prompt}
      end,
      image: fn _binary, _mime_type -> :image end do
      with_mock ReqLLM,
        generate_text: fn _model, _prompt_messages, _opts -> {:ok, :mock_response} end do
        with_mock ReqLLM.Response, text: fn :mock_response -> "  caption ok  " end do
          assert {:ok, "caption ok"} =
                   AshAiVision.caption(Base.encode64("fake"),
                     model: "openrouter:test",
                     language: "zh"
                   )

          assert_receive {:prompt, prompt}
          assert prompt =~ "Reply in zh."
        end
      end
    end
  end

  test "caption default prompt falls back to en" do
    with_mock ReqLLM.Message.ContentPart,
      text: fn prompt ->
        send(self(), {:prompt, prompt})
        {:text, prompt}
      end,
      image: fn _binary, _mime_type -> :image end do
      with_mock ReqLLM,
        generate_text: fn _model, _prompt_messages, _opts -> {:ok, :mock_response} end do
        with_mock ReqLLM.Response, text: fn :mock_response -> "ok" end do
          assert {:ok, "ok"} =
                   AshAiVision.caption(Base.encode64("fake"), model: "openrouter:test")

          assert_receive {:prompt, prompt}
          assert prompt =~ "Reply in en."
        end
      end
    end
  end
end
