export const AskAiUrlSync = {
  mounted() {
    this.handleSyncUrl = (event) => {
      const nextConversationId = event.detail?.conversation_id
      const url = new URL(window.location.href)

      if (nextConversationId) {
        url.searchParams.set("conversation_id", nextConversationId)
      } else {
        url.searchParams.delete("conversation_id")
      }

      window.history.replaceState(window.history.state, "", url.toString())
    }

    window.addEventListener("phx:ask_ai_sync_url", this.handleSyncUrl)

    const initialConversationId = new URL(window.location.href).searchParams.get("conversation_id")
    if (initialConversationId) {
      this.pushEvent("init-conversation-from-url", { conversation_id: initialConversationId })
    }
  },

  destroyed() {
    window.removeEventListener("phx:ask_ai_sync_url", this.handleSyncUrl)
  },
}
