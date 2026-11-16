---
name: writing-a-design-brief
description: Writes or updates DESIGN.md, the project's design brief — the chosen website personality (one of the seven or a custom one), the audience, and a machine-readable tokens block (font families, type scale, palette with tints and shades, spacing scale, radius, shadows, icon pack, and rules the style deliberately relaxes) that the web-design hooks lint against. Use when starting a new website or web app design, after choosing a personality, when the user runs /design-brief, or when the design tokens change.
---

# Design brief (DESIGN.md)

`DESIGN.md` lives at the project root. It is the single record of the design decisions, read by
people, by the reviewer agents, and — through its `tokens` block — by the hooks.

## Format

````markdown
# Design brief

## Personality
Startup/Upbeat, with a calm palette. Why: a scheduling tool for small clinics — modern and
trustworthy, not clinical.

## Audience and goal
Clinic owners on desktop and mobile. Primary action: start a free trial.

```tokens
personality: startup-upbeat
font-families: Inter
icon-pack: lucide
type-scale: 12 14 16 18 20 24 30 36 44 52 62
spacing-scale: 2 4 8 12 16 24 32 48 64 80 96 128
palette: primary #4f46e5; grey #334155; accent #f59e0b
radius: 4 8 16 9999
shadows: sm 0 1px 3px rgba(0,0,0,.1); md 0 4px 12px rgba(0,0,0,.08); lg 0 24px 48px rgba(0,0,0,.12)
```

## Notes
- Headings 700, body 400, body text 18px.
- Images: real clinic staff photos, warm light; no generic stock.
````

## A custom style

When none of the seven fits, the brief defines its own personality. The `## Personality` section
describes it by ingredient, and the tokens follow from that description:

````markdown
# Design brief

## Personality
Custom — neo-brutalist. A developer tool that should feel raw and direct.

| Ingredient | Choice |
|---|---|
| Typography | Space Grotesk for everything, big and bold; JetBrains Mono for code |
| Colour | Off-white background, near-black ink, one acid-yellow accent |
| Images | Product screenshots in thick black frames; no photography |
| Icons | Phosphor bold |
| Shadows | Hard offset shadows in solid black, no blur |
| Border-radius | None |
| Layout | Visible grid, thick borders between sections, oversized headings |

## Relaxed rules
- SHADOW-03: the hard black offset shadow is the signature of the style.

```tokens
personality: custom — neo-brutalist
font-families: Space Grotesk
icon-pack: phosphor
type-scale: 14 16 20 28 40 64 96
spacing-scale: 4 8 16 24 32 48 64 96
radius: 0
relax: SHADOW-03
```
````

For an existing project that matches none of the seven, describe what the code already does: the
families, colours, radii, spacing and sizes actually in use. The brief then records the design as
it is, and the hooks keep new work consistent with it.

## The tokens block

- Opens with a fence line that reads exactly ```` ```tokens ```` and closes with ```` ``` ````.
- One `key: value` per line. Keys are lowercase.
- **Read by the hooks** (leave a key out to fall back to the generic rules):
  - `font-families` — comma-separated; any other family is flagged.
  - `icon-pack` — any other pack is flagged.
  - `spacing-scale` — px numbers; margin, padding and gap off the scale are flagged.
  - `type-scale` — px numbers; any literal font-size off the scale is flagged.
  - `radius` — px numbers; border-radius off the scale is flagged. `0` and percentages are always
    allowed; a value of 999 or more means pill, and allows any pill radius.
  - `relax` — rule IDs the style deliberately breaks, comma-separated (e.g. `SHADOW-03, TYPO-13`).
    They are not reported. Give each a reason under `## Relaxed rules`. `COLOR-11` (contrast) and
    `TYPO-05` (body-text size) cannot be relaxed and are still reported if listed.
- **Read by people and agents:** `personality` (a slug such as `startup-upbeat`, or
  `custom — <label>`), `palette`, `shadows`.

## Writing it

1. Settle the personality first (`choosing-a-website-personality`), with a one-line reason. If
   none of the seven fits, write a custom one with its ingredient table.
2. Derive each token from the personality table (or the custom ingredients), then write the
   block. Add `relax` only for rules the style breaks on purpose, after confirming them with the
   user.
3. Mirror the tokens into code once — `:root` custom properties, the Tailwind theme, or a CSS-in-JS
   theme — and use only those in components.
4. When the design changes, update DESIGN.md in the same change, so the hooks check against the
   current decisions.
