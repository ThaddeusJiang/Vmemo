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
      with_mock Vmemo.Ai.AshAiVision,
        caption: fn _image_base64, opts ->
          send(self(), {:caption_opts, opts})
          {:ok, "中文描述"}
        end do
        assert {:ok, "中文描述"} =
                 Caption.generate_caption(Base.encode64("img"),
                   user_id: user.id,
                   mime_type: "image/png"
                 )

        assert_receive {:caption_opts, opts}
        assert opts[:language] == "zh"
      end
    end
  end

  test "generate_caption falls back to en when user_id is missing" do
    with_mock Vmemo.Ai.VisionConfig, resolve: fn -> %{model: "openrouter:test"} end do
      with_mock Vmemo.Ai.AshAiVision,
        caption: fn _image_base64, opts ->
          send(self(), {:caption_opts, opts})
          {:ok, "English description"}
        end do
        assert {:ok, "English description"} =
                 Caption.generate_caption(Base.encode64("img"), mime_type: "image/png")

        assert_receive {:caption_opts, opts}
        assert opts[:language] == "en"
      end
    end
  end
end
