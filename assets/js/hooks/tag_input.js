import Choices from "../../vendor/choices.min.js"

export const TagInput = {
  mounted() {
    this.initChoices()
  },

  updated() {
    this.destroyChoices()
    this.initChoices()
  },

  destroyed() {
    this.destroyChoices()
  },

  initChoices() {
    this.suppress = false

    this.choices = new Choices(this.el, {
      removeItemButton: true,
      duplicateItemsAllowed: false,
      shouldSort: false,
      searchEnabled: true,
      searchResultLimit: 8,
      placeholder: true,
      placeholderValue: this.el.dataset.placeholder || "English Grammar",
      noResultsText: "",
      noChoicesText: "",
      itemSelectText: "",
      addItemText: (value) => `Press Enter to add \"${value}\"`,
      maxItemText: () => "",
      addItems: true,
      addChoices: true,
      delimiter: ",",
      editItems: false,
    })

    this.el.addEventListener("addItem", (event) => {
      if (this.suppress) return
      const value = (event.detail.value || "").trim()
      if (!value) return
      this.pushEvent("add-tag", { tag_input: value })
    })

    this.el.addEventListener("removeItem", (event) => {
      if (this.suppress) return
      const value = (event.detail.value || "").trim()
      if (!value) return
      this.pushEvent("remove-tag", { name: value })
    })

    this.syncFromDom()

    if (this.el.nextElementSibling?.classList?.contains("choices")) {
      this.el.nextElementSibling.classList.add("is-ready")
    }
  },

  syncFromDom() {
    if (!this.choices) return

    const selectedValues = Array.from(this.el.selectedOptions).map((option) => option.value)

    this.suppress = true
    this.choices.removeActiveItems()

    selectedValues.forEach((value) => {
      this.choices.setChoiceByValue(value)
    })

    this.suppress = false
  },

  destroyChoices() {
    if (this.el.nextElementSibling?.classList?.contains("choices")) {
      this.el.nextElementSibling.classList.remove("is-ready")
    }

    if (this.choices) {
      this.choices.destroy()
      this.choices = null
    }
  },
}
