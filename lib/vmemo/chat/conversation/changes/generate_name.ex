defmodule Vmemo.Chat.Conversation.Changes.GenerateName do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  import ReqLLM.Context

  alias Vmemo.Account

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      conversation = changeset.data

      messages =
        Vmemo.Chat.Message
        |> Ash.Query.filter(conversation_id == ^conversation.id)
        |> Ash.Query.limit(10)
        |> Ash.Query.select([:text, :source])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!(scope: context)

      prompt_messages =
        [
          system("""
          Provide a short name for the current conversation.
          2-8 words, preferring more succinct names.
          Language: #{Account.preferred_language(context.actor)}.
          RESPOND WITH ONLY THE NEW CONVERSATION NAME.
          """)
        ] ++
          Enum.map(messages, &message_to_prompt_item/1)

      ReqLLM.generate_text(resolve_model(), prompt_messages)
      |> case do
        {:ok, response} ->
          title = ReqLLM.Response.text(response) |> to_string() |> String.trim()
          Ash.Changeset.force_change_attribute(changeset, :title, title)

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp resolve_model do
    Application.fetch_env!(:vmemo, :openrouter_chat_model)
  end

  defp message_to_prompt_item(%{source: :agent, text: text}), do: assistant(text || "")
  defp message_to_prompt_item(%{text: text}), do: user(text || "")
end
