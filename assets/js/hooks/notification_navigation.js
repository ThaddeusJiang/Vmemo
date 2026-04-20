export const NotificationTransitionLink = {
  mounted() {
    this.onClick = (event) => {
      if (
        event.defaultPrevented ||
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
      ) {
        return
      }

      const href = this.el.getAttribute("href")
      if (!href || typeof document.startViewTransition !== "function") return

      event.preventDefault()

      const transitionName = this.el.dataset.transitionName
      if (transitionName) {
        window.sessionStorage.setItem("vmemo:notification-transition", transitionName)
      }

      document.startViewTransition(() => {
        window.location.assign(href)
      })
    }

    this.el.addEventListener("click", this.onClick)
  },

  destroyed() {
    if (this.onClick) {
      this.el.removeEventListener("click", this.onClick)
    }
  },
}
