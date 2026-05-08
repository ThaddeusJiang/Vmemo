export const SearchSubmitOnEnter = {
  mounted() {
    this.isComposing = false

    this.onCompositionStart = () => {
      this.isComposing = true
    }

    this.onCompositionEnd = () => {
      this.isComposing = false
    }

    this.onKeyDown = (event) => {
      if (event.key !== "Enter") return

      const nativeComposing = event.isComposing || event.keyCode === 229
      if (this.isComposing || nativeComposing) {
        return
      }

      const form = this.el.form
      if (!form) return

      event.preventDefault()
      form.requestSubmit()
    }

    this.el.addEventListener("compositionstart", this.onCompositionStart)
    this.el.addEventListener("compositionend", this.onCompositionEnd)
    this.el.addEventListener("keydown", this.onKeyDown)
  },

  destroyed() {
    this.el.removeEventListener("compositionstart", this.onCompositionStart)
    this.el.removeEventListener("compositionend", this.onCompositionEnd)
    this.el.removeEventListener("keydown", this.onKeyDown)
  },
}
