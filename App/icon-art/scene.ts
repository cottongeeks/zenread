import paper from 'paper'
import { gradient, type Artwork, type Random } from '../../src/index.ts'

const colors = {
  fill: ['#2a2433', '#121016'],
  coral: '#f2ad6b',
  blue: '#87bfff',
  lavender: '#dbccf5',
  heading: '#f5d199',
  body: '#ece7df',
}

/** The reading column: left edge, full line length, and line metrics. */
const column = { left: 232, width: 560, heading: { y: 294, height: 76 }, body: { y: 446, height: 46, pitch: 100, lines: 4 } }

// LAYER=<name> draws one icon layer on a transparent canvas; unset draws the flat preview.
const only = process.env.LAYER as 'backdrop' | 'heading' | 'body' | undefined

export default {
  width: 1024,
  height: 1024,
  seed: 'mac-reader',
  draw({ width, height, random }) {
    if (!only) {
      new paper.Layer({ name: 'fill' })
      new paper.Path.Rectangle({
        name: 'fill-gradient',
        point: [0, 0],
        size: [width, height],
        fillColor: gradient([0, 0], [0, height], colors.fill),
      })
    }
    if (!only || only === 'backdrop') backdrop()
    if (!only || only === 'heading') {
      new paper.Layer({ name: 'heading' })
      words('heading-words', column.heading.y, column.heading.height, column.width * 0.62, colors.heading, random('heading'))
    }
    if (!only || only === 'body') {
      new paper.Layer({ name: 'body' })
      const { y, height: h, pitch, lines } = column.body
      for (let i = 0; i < lines; i++) {
        const rng = random(`line-${i}`)
        const last = i === lines - 1
        const length = last ? column.width * 0.5 : column.width * rng.range(0.9, 1)
        words(`line-${i}`, y + i * pitch, h, length, colors.body, rng)
      }
    }
  },
} satisfies Artwork

/** Soft glows of colour, as if the desktop behind were blurred. */
function backdrop() {
  new paper.Layer({ name: 'backdrop' })
  const glows: [string, paper.PointLike, number, string][] = [
    ['glow-coral', [210, 170], 560, colors.coral],
    ['glow-blue', [880, 900], 620, colors.blue],
    ['glow-lavender', [960, 260], 420, colors.lavender],
  ]
  for (const [name, center, radius, color] of glows) {
    const c = new paper.Point(center)
    new paper.Path.Circle({
      name,
      center: c,
      radius,
      fillColor: gradient(c, c.add([radius, 0]), [[withAlpha(color, 0.55), 0], [withAlpha(color, 0.22), 0.45], [withAlpha(color, 0), 1]], true),
    })
  }
}

/** One line of text as rounded "words" filling `length` from the column's left edge. */
function words(name: string, y: number, height: number, length: number, color: string, rng: Random) {
  const line = new paper.Group({ name })
  const gap = height * 0.55
  let x = column.left
  const end = column.left + length
  let i = 0
  while (x < end) {
    let w = rng.range(height * 1.6, height * 4.2)
    // Don't leave a sliver of a word at the end of the line.
    if (end - (x + w + gap) < height * 1.4) w = end - x
    new paper.Path.Rectangle({
      name: `${name}-word-${i++}`,
      parent: line,
      rectangle: new paper.Rectangle(x, y - height / 2, w, height),
      radius: height / 2,
      fillColor: color,
    })
    x += w + gap
  }
}

function withAlpha(hex: string, alpha: number): paper.Color {
  const color = new paper.Color(hex)
  color.alpha = alpha
  return color
}
