// Ambient starfield rendered on a fixed full-viewport canvas behind the app.
// One canvas, created once, persisting across LiveView navigations. Honors
// prefers-reduced-motion by drawing a single static frame.
export function startStarfield() {
  if (document.getElementById("stars")) return

  const canvas = document.createElement("canvas")
  canvas.id = "stars"
  const mount = () => document.body.prepend(canvas)
  if (document.body) mount()
  else document.addEventListener("DOMContentLoaded", mount, {once: true})

  const ctx = canvas.getContext("2d")
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  let stars = []

  function seed() {
    const w = (canvas.width = window.innerWidth)
    const h = (canvas.height = window.innerHeight)
    const count = Math.round((w * h) / 9000)
    stars = []
    for (let i = 0; i < count; i++) {
      stars.push({
        x: Math.random() * w,
        y: Math.random() * h,
        r: Math.random() * 1.3 + 0.2,
        a: Math.random() * 0.6 + 0.15,
        tw: Math.random() * 0.02 + 0.004,
        ph: Math.random() * Math.PI * 2
      })
    }
  }

  function draw(time) {
    const w = canvas.width
    const h = canvas.height
    ctx.clearRect(0, 0, w, h)
    for (const s of stars) {
      const a = reduce ? s.a : s.a * (0.6 + 0.4 * Math.sin(time * s.tw + s.ph))
      ctx.beginPath()
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2)
      ctx.fillStyle = `rgba(200, 210, 255, ${a.toFixed(3)})`
      ctx.fill()
    }
    if (!reduce) requestAnimationFrame(draw)
  }

  seed()
  if (reduce) draw(0)
  else requestAnimationFrame(draw)

  let resizeTimer
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer)
    resizeTimer = setTimeout(() => {
      seed()
      if (reduce) draw(0)
    }, 150)
  })
}
