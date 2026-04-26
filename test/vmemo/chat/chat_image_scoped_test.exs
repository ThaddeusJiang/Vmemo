defmodule Vmemo.ChatImageScopedTest do
  use Vmemo.DataCase, async: true

  import Vmemo.AccountFixtures

  alias Vmemo.Chat
  alias Vmemo.Chat.AiRouter
  alias Vmemo.Chat.Commands
  alias Vmemo.Memo.Image

  describe "image scoped conversation" do
    test "allows multiple conversations for one image and supports filter by initial image" do
      user = user_fixture()
      image = create_image!(user)

      {:ok, c1} =
        Chat.create_image_scoped_conversation(%{title: "first", image_id: image.id}, actor: user)

      {:ok, c2} =
        Chat.create_image_scoped_conversation(%{title: "second", image_id: image.id}, actor: user)

      filtered = Chat.list_conversations_by_initial_image(user, image.id)
      filtered_ids = MapSet.new(Enum.map(filtered, & &1.id))

      assert MapSet.member?(filtered_ids, c1.id)
      assert MapSet.member?(filtered_ids, c2.id)
      assert c1.id != c2.id
    end

    test "clear/compact updates context and keeps history" do
      user = user_fixture()
      image = create_image!(user)

      {:ok, conversation} =
        Chat.create_image_scoped_conversation(%{title: "ctx", image_id: image.id}, actor: user)

      now = DateTime.utc_now()

      {:ok, compacted} = Chat.compact_context(conversation, now, "summary", actor: user)

      assert compacted.context_summary == "summary"
      assert compacted.context_reset_at

      later = DateTime.add(now, 1, :second)
      {:ok, cleared} = Chat.clear_context(compacted, later, actor: user)
      assert is_nil(cleared.context_summary)
      assert cleared.context_reset_at
    end
  end

  describe "commands" do
    test "parses slash commands" do
      assert Commands.parse("/clear") == {:ok, :clear}
      assert Commands.parse("/compact") == {:ok, :compact}
      assert Commands.parse("hello") == :no_command
    end
  end

  describe "ai router for image-scoped chat" do
    test "routes regular text to query tool in image-scoped conversations" do
      conversation = %{kind: "image_scoped", image_id: Ash.UUID.generate()}

      assert {:ok, %{tool_name: "query", provider: "openrouter"}} =
               AiRouter.route_image_tool(conversation, "解释一下这张图", nil)
    end

    test "keeps general chat path when asking to search other images" do
      conversation = %{kind: "image_scoped", image_id: Ash.UUID.generate()}

      assert :skip =
               AiRouter.route_image_tool(conversation, "帮我找其他图片", nil)
    end
  end

  defp create_image!(user) do
    attrs = %{
      url: "/storage/v1/#{user.id}/images/test.jpg",
      note: "note",
      caption: "caption",
      user_id: user.id,
      file_id: "test.jpg"
    }

    case Image.create_immediate(attrs, actor: user) do
      {:ok, image} -> image
      {:error, error} -> raise "failed to create image: #{inspect(error)}"
    end
  end
end
