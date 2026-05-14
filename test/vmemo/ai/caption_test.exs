defmodule Vmemo.Ai.CaptionTest do
  use Vmemo.DataCase, async: false

  import Mock
  import Vmemo.AccountFixtures

  alias Vmemo.Account
  alias Vmemo.Ai.Caption

  test "generate_caption passes profile language to vision caption" do
    user = user_fixture()
    {:ok, _profile} = Account.upsert_user_profile(user, %{name: "Tester", language: "zh"})

    with_mock Vmemo.Ai.VisionConfig, resolve: fn -> %{model: "openrouter:test"} end do
      with_mock Vmemo.Ai.AshAiVision, [:passthrough],
        caption: fn _image_base64, opts ->
          send(self(), {:caption_opts, opts})
          {:ok, "中文描述"}
        end do
        with_mock ReqLLM, generate_text: fn _model, _messages, _opts -> {:error, :skip} end do
          assert {:ok, "中文描述"} =
                   Caption.generate_caption(Base.encode64("img"),
                     user_id: user.id,
                     mime_type: "image/png"
                   )
        end

        assert_receive {:caption_opts, opts}
        assert opts[:language] == "zh"
      end
    end
  end

  test "generate_caption falls back to en when user_id is missing" do
    with_mock Vmemo.Ai.VisionConfig, resolve: fn -> %{model: "openrouter:test"} end do
      with_mock Vmemo.Ai.AshAiVision, [:passthrough],
        caption: fn _image_base64, opts ->
          send(self(), {:caption_opts, opts})
          {:ok, "English description"}
        end do
        with_mock ReqLLM, generate_text: fn _model, _messages, _opts -> {:error, :skip} end do
          assert {:ok, "English description"} =
                   Caption.generate_caption(Base.encode64("img"), mime_type: "image/png")
        end

        assert_receive {:caption_opts, opts}
        assert opts[:language] == "en"
      end
    end
  end

  test "generate_caption returns plain caption text without appending tags" do
    with_mock Vmemo.Ai.VisionConfig, resolve: fn -> %{model: "openrouter:test"} end do
      with_mock Vmemo.Ai.AshAiVision, [:passthrough],
        caption: fn _image_base64, _opts -> {:ok, "A cat on desk"} end do
        with_mock ReqLLM, generate_text: fn _model, _messages, _opts -> {:ok, :ok} end do
          with_mock ReqLLM.Response, text: fn :ok -> ~s(["Pets", "Indoor Scene"]) end do
            assert {:ok, "A cat on desk"} =
                     Caption.generate_caption(Base.encode64("img"), mime_type: "image/png")
          end
        end
      end
    end
  end

  test "suggest_tags_from_caption normalizes model JSON response" do
    with_mock ReqLLM, generate_text: fn _model, _messages, _opts -> {:ok, :ok} end do
      with_mock ReqLLM.Response, text: fn :ok -> ~s([" English  Grammar ","日本語", ""]) end do
        assert {:ok, ["English Grammar", "日本語"]} =
                 Caption.suggest_tags_from_caption("caption", user_id: nil)
      end
    end
  end

  test "generate_caption_and_tags returns structured caption and tags" do
    with_mock Vmemo.Ai.VisionConfig, resolve: fn -> %{model: "openrouter:test"} end do
      with_mock Vmemo.Ai.AshAiVision, [:passthrough],
        generate_object: fn _image_base64, _prompt, _schema, _opts ->
          {:ok, %{object: %{caption: "A cat on desk", tags: [" Pets ", "Indoor Scene", ""]}}}
        end do
        assert {:ok, %{caption: "A cat on desk", tags: ["Pets", "Indoor Scene"]}} =
                 Caption.generate_caption_and_tags(Base.encode64("img"), mime_type: "image/png")
      end
    end
  end
end
