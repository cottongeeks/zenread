# Mac Reader app icon

A vector-art artwork: it renders in vector-art as `artworks/mac-reader-icon/`
(see the README's App icon section).

## Subject

The app itself: a centred reading column of text over a blurred, colourful
desktop. A gold heading line above four ivory lines of "words" (rounded bars),
the last one short like the end of a paragraph.

## Use

A macOS 26+ Icon Composer icon (`AppIcon.icon`). Each layer is rendered on its
own with `LAYER=<name> pnpm art:render mac-reader-icon` and becomes one SVG in
`AppIcon.icon/Assets/`; macOS draws the squircle mask, the Liquid Glass and the
dark, tinted and clear looks. Without `LAYER` the scene draws every layer over
the background fill, as a flat preview of the composition.

- `backdrop`: soft colour blobs, no glass. The blurred desktop.
- `heading`: the gold heading words, glass.
- `body`: the ivory body words, glass.

The background fill is `linear-gradient` in `icon.json`; `fill` here only
previews it.

## Style

Flat shapes, filled only (no strokes), large enough to read at 32 px. Keep the
column inside the central ~60% of the canvas.

## Palette

- Background: ink `#2a2433` to `#121016`, top to bottom.
- Backdrop: coral `#f2ad6b`, blue `#87bfff`, lavender `#dbccf5`, all soft.
- Heading `#f5d199` (the app's heading colour), body `#ece7df`.

## Locked

Nothing yet.
