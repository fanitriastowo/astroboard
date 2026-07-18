// Dependency-free drag-and-drop for board cards. Attached to each list's card
// container (#cards-<id>, data-list-id). Uses event delegation so it survives
// LiveView stream updates. On drop it computes the target position from the
// pointer and pushes "move_card" to the server, which persists + broadcasts;
// the canonical order comes back via a stream reset.
export const Drag = {
  mounted() {
    const el = this.el

    el.addEventListener("dragstart", (e) => {
      const card = e.target.closest("[data-card-id]")
      if (!card) return
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData("text/plain", card.dataset.cardId)
      // Defer so the drag image is captured before the card dims.
      requestAnimationFrame(() => card.classList.add("opacity-40"))
    })

    el.addEventListener("dragend", (e) => {
      const card = e.target.closest("[data-card-id]")
      if (card) card.classList.remove("opacity-40")
    })

    el.addEventListener("dragover", (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
      el.classList.add("ring-1", "ring-primary/40", "rounded-2xl")
    })

    el.addEventListener("dragleave", (e) => {
      if (!el.contains(e.relatedTarget)) {
        el.classList.remove("ring-1", "ring-primary/40", "rounded-2xl")
      }
    })

    el.addEventListener("drop", (e) => {
      e.preventDefault()
      el.classList.remove("ring-1", "ring-primary/40", "rounded-2xl")

      const cardId = e.dataTransfer.getData("text/plain")
      if (!cardId) return

      const cards = [...el.querySelectorAll("[data-card-id]")].filter(
        (c) => c.dataset.cardId !== cardId
      )

      let position = cards.length
      for (let i = 0; i < cards.length; i++) {
        const rect = cards[i].getBoundingClientRect()
        if (e.clientY < rect.top + rect.height / 2) {
          position = i
          break
        }
      }

      this.pushEvent("move_card", {
        card_id: cardId,
        list_id: el.dataset.listId,
        position
      })
    })
  }
}
