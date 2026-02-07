export const DirectoryUpload = {
  mounted() {
    this.applyAttributes()
  },
  updated() {
    this.applyAttributes()
  },
  applyAttributes() {
    const input = this.el.querySelector("input[type='file']")
    if (!input) return
    input.setAttribute("webkitdirectory", "")
    input.setAttribute("directory", "")
    input.setAttribute("multiple", "")
    input.setAttribute("mozdirectory", "")
  },
}
