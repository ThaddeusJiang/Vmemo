export const Resizer = {
  mounted() {
    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const width = entry.contentRect.width

        let col = 2

        if (width >= 1024) {
          col = 4
        } else if (width >= 768) {
          col = 3
        }

        if (this.el.dataset.col != col) {
          this.el.dataset.col = col

          this.pushEventTo(this.el, "change_col", {
            col: col,
          })
        }
      }
    })

    resizeObserver.observe(this.el)
  },
}
