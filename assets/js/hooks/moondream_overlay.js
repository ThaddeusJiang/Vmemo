export const MoondreamOverlay = {
  mounted() {
    this.updateOverlay()

    // Update when image loads or resizes
    const img = this.el.querySelector("img")
    if (img) {
      img.addEventListener("load", () => this.updateOverlay())
    }

    // Use ResizeObserver if available
    if (window.ResizeObserver) {
      const observer = new ResizeObserver(() => this.updateOverlay())
      observer.observe(this.el)
    }
  },

  updated() {
    this.updateOverlay()
  },

  updateOverlay() {
    const img = this.el.querySelector("img")
    if (!img) return

    // Get image natural (original) dimensions
    const naturalWidth = img.naturalWidth || img.width
    const naturalHeight = img.naturalHeight || img.height

    // Get displayed dimensions
    const displayWidth = img.offsetWidth
    const displayHeight = img.offsetHeight

    if (naturalWidth === 0 || naturalHeight === 0) return

    // Update point coordinates if present (HTML span elements)
    const pointMarkers = this.el.querySelectorAll("span[data-x][data-y]")
    pointMarkers.forEach((pointMarker) => {
      let x = parseFloat(pointMarker.getAttribute("data-x") || 0)
      let y = parseFloat(pointMarker.getAttribute("data-y") || 0)

      // Check if coordinates are normalized (0-1 range)
      // If so, convert to pixel coordinates
      if (x >= 0 && x <= 1 && y >= 0 && y <= 1) {
        x = x * naturalWidth
        y = y * naturalHeight
      }

      // Convert to display coordinates
      const displayX = (x / naturalWidth) * displayWidth
      const displayY = (y / naturalHeight) * displayHeight

      // Set position using CSS
      pointMarker.style.left = `${displayX}px`
      pointMarker.style.top = `${displayY}px`
    })

    // Update SVG coordinates if present (for detect results)
    const svg = this.el.querySelector("svg")
    if (svg) {
      // Update SVG viewBox to match natural dimensions
      svg.setAttribute("viewBox", `0 0 ${naturalWidth} ${naturalHeight}`)
      svg.setAttribute("width", displayWidth)
      svg.setAttribute("height", displayHeight)

      // Update rectangle coordinates if present
      const rects = svg.querySelectorAll("rect")
      rects.forEach((rect) => {
        let x1 = parseFloat(rect.getAttribute("data-x1") || rect.getAttribute("x") || 0)
        let y1 = parseFloat(rect.getAttribute("data-y1") || rect.getAttribute("y") || 0)
        let x2 = parseFloat(rect.getAttribute("data-x2") || x1 + parseFloat(rect.getAttribute("width") || 0))
        let y2 = parseFloat(rect.getAttribute("data-y2") || y1 + parseFloat(rect.getAttribute("height") || 0))

        // Check if coordinates are normalized (0-1 range)
        // If so, convert to pixel coordinates
        if (x1 >= 0 && x1 <= 1 && y1 >= 0 && y1 <= 1 && x2 >= 0 && x2 <= 1 && y2 >= 0 && y2 <= 1) {
          x1 = x1 * naturalWidth
          y1 = y1 * naturalHeight
          x2 = x2 * naturalWidth
          y2 = y2 * naturalHeight
        }

        // Set coordinates in SVG coordinate system (natural dimensions)
        rect.setAttribute("x", x1)
        rect.setAttribute("y", y1)
        rect.setAttribute("width", x2 - x1)
        rect.setAttribute("height", y2 - y1)
      })

      // Update text positions if present
      const texts = svg.querySelectorAll("text")
      texts.forEach((text) => {
        const x = parseFloat(text.getAttribute("data-x") || text.getAttribute("x") || 0)
        const y = parseFloat(text.getAttribute("data-y") || text.getAttribute("y") || 0)

        // Coordinates are assumed to be in pixels relative to natural image size
        // Set them directly in SVG coordinate system (natural dimensions)
        text.setAttribute("x", x)
        text.setAttribute("y", y)
      })
    }
  },
}
