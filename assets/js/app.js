// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "../../deps/phoenix_html/priv/static/phoenix_html.js"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "../../deps/phoenix/priv/static/phoenix.mjs"
import {LiveSocket} from "../../deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js"
import topbar from "../vendor/topbar"

// Hooks for LiveView
let Hooks = {}

// Auto-dismiss flash messages after 5 seconds
Hooks.AutoDismiss = {
  mounted() {
    this.timeout = setTimeout(() => {
      this.el.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
      this.el.style.opacity = "0"
      this.el.style.transform = "translateX(100%)"
      setTimeout(() => {
        this.pushEvent("lv:clear-flash", {key: this.el.dataset.kind})
        this.el.remove()
      }, 300)
    }, 5000)
  },
  destroyed() {
    clearTimeout(this.timeout)
  }
}

// Remember last selected project in localStorage
Hooks.RememberProject = {
  mounted() {
    this.restoreProject()
    
    // Save project when changed by user
    this.el.addEventListener('change', (e) => {
      if (e.target.value) {
        localStorage.setItem('lastSelectedProject', e.target.value)
      }
    })
  },
  
  updated() {
    // Restore after LiveView re-renders (e.g., after form submit)
    // Use setTimeout to ensure DOM is fully updated
    setTimeout(() => this.restoreProject(), 0)
  },
  
  restoreProject() {
    const savedProject = localStorage.getItem('lastSelectedProject')
    // Only restore if no project is currently selected and the saved project exists as an option
    if (savedProject && !this.el.value && this.el.querySelector(`option[value="${savedProject}"]`)) {
      this.el.value = savedProject
      // Dispatch change event so LiveView knows about the selection (for Week view)
      this.el.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#F7931A"}, shadowColor: "rgba(247, 147, 26, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
window.liveSocket = liveSocket