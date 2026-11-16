---
name: spacing-with-whitespace
description: Spaces web layouts with whitespace — lots between sections, a lot between groups, some between elements, whitespace instead of divider lines inside groups, proximity for things that belong together, more space for bigger text and icons, and every margin, padding and gap taken from a fixed spacing scale. Use when writing margin, padding, gap or Tailwind spacing utilities, laying out sections, cards, forms or navigation, or when a page feels cramped or loose.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Whitespace

## Rules: Whitespace (SPACE)
1. Use tons of whitespace between sections.
2. Use a lot of whitespace between groups of elements.
3. Use whitespace between elements.
4. Inside groups, prefer whitespace to divider lines.
5. The more elements belong together, the closer they sit.
6. Start with too much whitespace, then remove some.
7. Bigger text or icons need more whitespace.
8. Take every spacing value from a hard scale (e.g. multiples of 16px).

## Applying it

- **Default scale (px):** 2 / 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 80 / 96 / 128. See
  [references/spacing-scale.md](references/spacing-scale.md). Record a different one in
  DESIGN.md (`spacing-scale:`) and the hook checks against that instead.
- **Rough tiers** for a typical landing page:
  - between sections: 96–128px vertical padding
  - between groups (heading block → card grid): 48–64px
  - between elements in a group (title → text → button): 16–32px
  - inside a component (icon → label, label → input): 4–12px
- **Proximity:** a heading sits closer to the content it introduces than to the section above it.
  The gap above a heading is larger than the gap below it.
- **Lines vs space:** reach for a border only when space alone fails, e.g. dense tables.
- **Tailwind:** stay on the default spacing steps; `p-[13px]`-style arbitrary values are the
  ones the hook flags.

## What the hook checks

`SPACE-08` margin, padding and gap values off the scale (px and rem are converted; `em`, `%`,
`auto` and anything below 2px are left alone). Grouping, proximity and section rhythm are the
`design-reviewer` agent's call.
