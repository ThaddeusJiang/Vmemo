export const FullscreenDrop = {
  mounted() {
    this.dragDepth = 0
    this.active = false

    this.onDragEnter = (event) => {
      if (!this.hasFile(event)) return
      event.preventDefault()
      this.dragDepth += 1
      this.show()
    }

    this.onDragOver = (event) => {
      if (!this.hasFile(event)) return
      event.preventDefault()
      this.show()
    }

    this.onDragLeave = (event) => {
      if (!this.hasFile(event)) return
      event.preventDefault()
      this.dragDepth = Math.max(this.dragDepth - 1, 0)
      if (this.dragDepth === 0) this.hide()
    }

    this.onDrop = (event) => {
      if (!this.hasFile(event)) return
      event.preventDefault()
      this.dragDepth = 0
      this.hide()
    }

    window.addEventListener("dragenter", this.onDragEnter)
    window.addEventListener("dragover", this.onDragOver)
    window.addEventListener("dragleave", this.onDragLeave)
    window.addEventListener("drop", this.onDrop)
  },

  destroyed() {
    window.removeEventListener("dragenter", this.onDragEnter)
    window.removeEventListener("dragover", this.onDragOver)
    window.removeEventListener("dragleave", this.onDragLeave)
    window.removeEventListener("drop", this.onDrop)
  },

  hasFile(event) {
    const types = event.dataTransfer?.types
    if (!types) return false
    return Array.from(types).includes("Files")
  },

  show() {
    if (this.active) return
    this.active = true
    this.el.classList.remove("hidden")
    this.el.classList.add("flex")
  },

  hide() {
    if (!this.active) return
    this.active = false
    this.el.classList.add("hidden")
    this.el.classList.remove("flex")
  },
}
