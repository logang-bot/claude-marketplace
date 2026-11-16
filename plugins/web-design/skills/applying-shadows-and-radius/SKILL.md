---
name: applying-shadows-and-radius
description: Applies box-shadows and border-radius on websites — shadows only when the personality allows, sparingly and light, in a small/medium/large scale by element size, changing on hover; radius matched to the typeface's roundness on buttons, images, icon shapes and standout sections. Use when writing box-shadow, border-radius, rounded-*, shadow-* or elevation styles, or styling cards, buttons, modals and popovers.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Shadows and border-radius

## Rules: Shadows (SHADOW)
1. Shadows are optional; use them only if they suit the personality.
2. Use shadows in small doses, not on every element.
3. Keep shadows light, never dark.
4. Small shadows for small elements that should stand out.
5. Medium shadows for larger areas that should stand out a bit more.
6. Large shadows for elements that float above the interface.
7. Try changing shadows on hover and click.
8. Bonus: try glows (coloured shadows).

## Rules: Border-radius (RADIUS)
1. Border-radius adds playfulness and makes a design less serious.
2. Match the radius to the typeface's roundness.
3. Use it on buttons, images, around icons, standout sections and similar.

## Applying it

- **One scale, three steps**, defined once:
  ```css
  :root {
    --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.06), 0 1px 3px rgba(0, 0, 0, 0.1);   /* buttons, chips */
    --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.08);                               /* cards */
    --shadow-lg: 0 24px 48px rgba(0, 0, 0, 0.12);                              /* modals, popovers */
  }
  .card:hover { box-shadow: var(--shadow-lg); transform: translateY(-2px); }
  ```
  Neutral shadow colours stay at alpha 0.25 or less. A glow is a shadow in the brand colour,
  e.g. `0 8px 24px rgba(99, 102, 241, 0.35)`.
- **Which personalities use shadows:** startup/upbeat and playful (yes), calm (soft), plain
  (barely), serious/elegant, minimalist, bold (usually none — they use lines or colour blocks).
- **Radius scale:** `--radius-sm: 4px; --radius-md: 8px; --radius-lg: 16px; --radius-full: 9999px`.
  Geometric or rounded typefaces (Nunito, Poppins) suit larger radii; serifs and sharp grotesques
  suit 0–4px. Nested elements use a smaller radius than their container (`inner = outer − padding`).

## What the hook checks

`SHADOW-03` neutral box-shadow colours above 0.25 alpha, or a shadow with no colour (it falls back
to the text colour at full opacity); `SHADOW-02` more than four distinct box-shadows in one file.
Radius fit is the `design-reviewer` agent's call.
