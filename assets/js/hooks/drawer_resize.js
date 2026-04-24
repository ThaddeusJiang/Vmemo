const clamp = (value, min, max) => Math.max(min, Math.min(max, value))

export const DrawerResize = {
  mounted() {
    this.storageKey = this.el.dataset.storageKey || "global-ask-ai-drawer-width"
    this.minWidth = Number.parseInt(this.el.dataset.minWidth || "420", 10)
    this.maxWidth = Number.parseInt(this.el.dataset.maxWidth || "960", 10)
    this.defaultWidth = Number.parseInt(this.el.dataset.defaultWidth || "640", 10)
    this.handle = this.el.querySelector("[data-role='drawer-resize-handle']")

    this.applyWidth(this.loadWidth())

    this.onPointerMove = (event) => {
      if (!this.dragging) return
      event.preventDefault()
      this.applyWidth(this.widthFromPointer(event.clientX))
    }

    this.onPointerUp = () => {
      if (!this.dragging) return
      this.dragging = false
      document.body.classList.remove("global-ask-ai-resizing")
      this.persistWidth(this.currentWidth)
    }

    this.onWindowResize = () => {
      this.applyWidth(this.currentWidth || this.loadWidth())
    }

    this.onPointerDown = (event) => {
      if (window.innerWidth < 1024) return
      this.dragging = true
      document.body.classList.add("global-ask-ai-resizing")
      event.preventDefault()
    }

    if (this.handle) {
      this.handle.addEventListener("pointerdown", this.onPointerDown)
    }

    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)
    window.addEventListener("resize", this.onWindowResize)
  },

  destroyed() {
    if (this.handle) {
      this.handle.removeEventListener("pointerdown", this.onPointerDown)
    }

    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
    window.removeEventListener("resize", this.onWindowResize)
    document.body.classList.remove("global-ask-ai-resizing")
  },

  widthFromPointer(pointerX) {
    const viewportWidth = window.innerWidth
    const maxAllowed = Math.min(this.maxWidth, viewportWidth)
    const calculated = viewportWidth - pointerX
    return clamp(calculated, this.minWidth, maxAllowed)
  },

  applyWidth(width) {
    const viewportWidth = window.innerWidth
    const maxAllowed = Math.min(this.maxWidth, viewportWidth)
    this.currentWidth = clamp(width, this.minWidth, maxAllowed)
    this.el.style.width = `${this.currentWidth}px`
  },

  loadWidth() {
    const saved = Number.parseInt(window.localStorage.getItem(this.storageKey) || "", 10)
    return Number.isFinite(saved) ? saved : this.defaultWidth
  },

  persistWidth(width) {
    if (!Number.isFinite(width)) return
    window.localStorage.setItem(this.storageKey, String(width))
  },
}
