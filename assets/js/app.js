// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

import { Resizer } from "./hooks/resizer"
import { InfiniteScroll } from "./hooks/infinite_scroll"
import { ImageLoader, applyImageFallback } from "./hooks/image_loader"
import { ClipboardMediaFetcher } from "./hooks/clipboard_media_fetcher"
import { Toast } from "./hooks/toast"
import { Focus } from "./hooks/focus"
import { MoondreamOverlay } from "./hooks/moondream_overlay"
import { DirectoryUpload } from "./hooks/directory_upload"
import { DrawerResize } from "./hooks/drawer_resize"

const FormatDatetime = {
  format() {
    const iso = this.el.dataset.iso
    if (!iso) return

    const date = new Date(iso)
    if (isNaN(date.getTime())) return

    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    const hours = String(date.getHours()).padStart(2, "0")
    const minutes = String(date.getMinutes()).padStart(2, "0")

    this.el.textContent = `${year}-${month}-${day} ${hours}:${minutes}`
  },
  mounted() {
    this.format()
  },
  updated() {
    this.format()
  },
}

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    Resizer,
    InfiniteScroll,
    ImageLoader,
    ClipboardMediaFetcher,
    Toast,
    Focus,
    MoondreamOverlay,
    DirectoryUpload,
    FormatDatetime,
    DrawerResize,
  },
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
})

// connect if there are any LiveViews on the page
liveSocket.connect()

document.addEventListener(
  "error",
  (event) => {
    const target = event.target
    if (!(target instanceof HTMLImageElement)) return
    applyImageFallback(target)
  },
  true
)

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("img").forEach((img) => {
    if (img.complete && (img.naturalWidth === 0 || img.naturalHeight === 0)) {
      applyImageFallback(img)
    }
  })

  syncThemeColorMeta()
})

// Handle form reset events from LiveView
window.addEventListener("phx:reset_form", (event) => {
  const { form_id } = event.detail
  const form = document.getElementById(form_id)
  if (form) {
    form.reset()
  }
})

// Handle copy to clipboard events from LiveView
window.addEventListener("phx:copy_to_clipboard", (event) => {
  const { text } = event.detail
  if (!text) return

  // Try modern Clipboard API first
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).catch((err) => {
      console.error("Failed to copy to clipboard:", err)
      // Fallback to old method if modern API fails
      copyToClipboardFallback(text)
    })
  } else {
    // Fallback to old method if Clipboard API is not available
    copyToClipboardFallback(text)
  }
})

// Fallback method for copying to clipboard
function copyToClipboardFallback(text) {
  const textArea = document.createElement("textarea")
  textArea.value = text
  textArea.style.position = "fixed"
  textArea.style.left = "-999999px"
  textArea.style.top = "-999999px"
  document.body.appendChild(textArea)
  textArea.focus()
  textArea.select()
  try {
    const successful = document.execCommand("copy")
    if (!successful) {
      console.error("Fallback copy command failed")
    }
  } catch (err) {
    console.error("Fallback copy failed:", err)
  }
  document.body.removeChild(textArea)
}

window.updateAppearancePreference = async (isDark) => {
  const appearance = isDark ? "dark" : "light"
  applyAppearanceWithTransition(appearance)

  try {
    await fetch("/profile/appearance", {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded;charset=UTF-8",
        "x-csrf-token": csrfToken,
        "x-requested-with": "XMLHttpRequest",
      },
      credentials: "same-origin",
      body: new URLSearchParams({ appearance }).toString(),
    })
  } catch (error) {
    console.error("Failed to persist appearance preference:", error)
  }
}

const applyAppearanceWithTransition = (appearance) => {
  const root = document.documentElement
  if (root.getAttribute("data-theme") === appearance) return

  updateThemeColorMeta(appearance)
  root.classList.add("theme-transition-active")
  root.classList.add(`theme-transition-to-${appearance}`)
  const radius = Math.ceil(Math.hypot(window.innerWidth, window.innerHeight))
  root.style.setProperty("--theme-transition-radius", `${radius}px`)

  const transition = document.startViewTransition(() => {
    root.setAttribute("data-theme", appearance)
  })

  transition.finished.finally(() => {
    root.classList.remove("theme-transition-active")
    root.classList.remove("theme-transition-to-light", "theme-transition-to-dark")
    root.style.removeProperty("--theme-transition-radius")
  })
}

const syncThemeColorMeta = () => {
  const appearance = document.documentElement.getAttribute("data-theme")
  if (appearance) updateThemeColorMeta(appearance)
}

const updateThemeColorMeta = (appearance) => {
  let meta = document.querySelector("meta[name='theme-color']")
  if (!meta) {
    meta = document.createElement("meta")
    meta.setAttribute("name", "theme-color")
    document.head.appendChild(meta)
  }

  const themeColor = appearance === "dark" ? "#282A36" : "#f8f8f8"
  meta.removeAttribute("media")
  meta.setAttribute("content", themeColor)
  document.querySelectorAll("meta[name='theme-color']").forEach((item) => {
    if (item !== meta) item.remove()
  })
}

// Smooth full-page navigation to reduce perceived flicker
const shouldHandleFullPageNav = (event, link) => {
  if (!link) return false
  if (event.defaultPrevented) return false
  if (event.button !== 0) return false
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false
  if (link.target && link.target !== "_self") return false
  if (link.hasAttribute("download")) return false
  if (link.dataset.phxLink) return false
  if (link.dataset.method) return false
  if (link.dataset.to) return false

  const url = new URL(link.href, window.location.origin)
  if (url.origin !== window.location.origin) return false
  if (url.pathname === window.location.pathname && url.search === window.location.search) return false
  if (url.hash && url.pathname === window.location.pathname && url.search === window.location.search) return false

  return true
}

document.addEventListener("click", (event) => {
  const link = event.target.closest("a[href]")
  if (!shouldHandleFullPageNav(event, link)) return

  event.preventDefault()
  document.documentElement.classList.add("is-page-leaving")
  window.setTimeout(() => {
    window.location.assign(link.href)
  }, 110)
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
