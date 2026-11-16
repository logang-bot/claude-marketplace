---
name: using-icons
description: Uses icons on websites — one good SVG icon pack matched to the typography's roundness and weight, icons that support text, feature blocks, labelled actions and bullet points, text-coloured by default, and enclosed in a shape instead of scaled past their design size. Use when adding icons, choosing an icon library (Lucide, Heroicons, Phosphor, Font Awesome, Material, react-icons...), or styling icon markup.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Icons

## Rules: Icons (ICON)
1. Use a good icon pack.
2. Use exactly one icon pack; never mix packs.
3. Use SVG icons or an icon font, never .png/.jpg.
4. Match roundness, weight and filled/outlined style to the typography.
5. Use icons as visual support for text.
6. Use icons in product feature blocks.
7. Label action icons, unless space is tight or the icon is 100% clear.
8. Icons work as bullet points.
9. Neutral icons use the text colour; a different colour draws attention.
10. Icons must make sense for the text or action they accompany.
11. Don't scale icons past their design size; enclose them in a shape.

## Applying it

- **Pick the pack from the personality**, then record it in DESIGN.md (`icon-pack:`):
  - thin, outline: Lucide, Feather, Heroicons outline, Phosphor light (minimalist, elegant)
  - balanced: Phosphor regular, Tabler, Remix (startup, neutral)
  - filled or bold: Heroicons solid, Phosphor bold/fill, Material Symbols (bold, plain)
  - rounded, duotone: Phosphor duotone (playful, calm)
- **Stroke weight follows the text weight:** a 1.5px stroke next to 400-weight text, 2px next
  to 600+.
- **Colour:** `color: currentColor` / `stroke="currentColor"` so icons inherit the text colour,
  then override it only where attention is wanted.
- **Size:** most packs are drawn for 20–24px. For a big feature icon, keep the glyph at 24–32px
  and put it in a tinted circle or rounded square:
  ```css
  .feature__icon { display: grid; place-items: center; width: 64px; height: 64px;
                   border-radius: 50%; background: var(--primary-50); color: var(--primary-600); }
  ```
- **Labels:** icon-only buttons need `aria-label`; decorative icons get `aria-hidden="true"`.

## What the hook checks

`ICON-02` more than one icon pack across the files a request touched (detected from classes,
imports, CDN links), or a pack other than DESIGN.md's; `ICON-03` icons served as raster images.
