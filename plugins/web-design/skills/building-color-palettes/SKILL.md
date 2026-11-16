---
name: building-color-palettes
description: Builds a web colour palette from the website personality — a deliberate main colour plus a grey, optional accents, tints and shades defined once as custom properties — and applies it to draw attention, accent sections, and keep text legible (never pure black, never too light, at least 4.5:1 contrast). Use when choosing colours, writing color, background, border or shadow colours in CSS, Tailwind or CSS-in-JS, theming, or adding dark sections.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Colour

## Rules: Colours (COLOR)
1. Match the main colour to the personality; colours convey meaning.
2. Choose a deliberate tone, never a random one or a CSS named colour.
3. The palette needs at least a main colour and a grey.
4. Add accent (secondary) colours only with a tool and some experience.
5. Create tints and shades (lighter and darker versions) for variety.
6. Use the main colour to draw attention to the most important elements.
7. Use colour for accents, or to make whole components or sections stand out.
8. Use the palette strategically in images and illustrations.
9. On dark backgrounds, use a tint of the background colour for text.
10. Text shouldn't be pure black; lighten it if it looks heavy.
11. Don't make text too light: check contrast (4.5:1 normal text, 3:1 large text).

## Applying it

- **Define once, reuse everywhere.** Put the palette in `:root` custom properties, a Tailwind
  theme, or a CSS-in-JS theme object, and reference it. A raw hex in a component is a palette
  leak.
- **Build tints and shades** from the main colour in ~10% steps (tools: tints.dev,
  maketintsandshades.com, uicolors.app). Name them by role or weight, e.g. `--primary-100 … 900`.
- **Greys:** pick a grey family slightly tinted toward the main colour; use the darkest shades for
  text (`#333`–`#555` territory on white), lighter ones for borders and backgrounds.
- **Main colour for attention:** primary buttons, active states, key links, highlights. If
  everything is the main colour, nothing is.
- **Dark sections:** text in a very light tint of the section's own colour, not pure white on a
  saturated block.
- **Contrast:** check every text/background pair (WebAIM contrast checker, Coolors contrast).
  Large text means 24px+, or 18.66px+ bold.

Palette direction per personality is in the `choosing-a-website-personality` skill's reference.
See [references/palette-template.md](references/palette-template.md) for a starter token set.

## What the hook checks

`COLOR-02` CSS named colours, `COLOR-03` more than 16 distinct raw colour literals in a file (no
palette), `COLOR-10` pure black text, `COLOR-11` contrast below 4.5:1 (3:1 for large text) when a
rule, inline style or element sets both text colour and background. Custom properties, SCSS/LESS
variables and Tailwind neutral classes are resolved.
