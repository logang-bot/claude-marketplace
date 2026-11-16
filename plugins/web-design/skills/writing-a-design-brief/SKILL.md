---
name: writing-a-design-brief
description: Writes or updates DESIGN.md, the project's design brief — the chosen website personality, the audience, and a machine-readable tokens block (font families, type scale, palette with tints and shades, spacing scale, radius, shadows, icon pack) that the web-design hooks lint against. Use when starting a new website or web app design, after choosing a personality, when the user runs /design-brief, or when the design tokens change.
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

## The tokens block

- Opens with a fence line that reads exactly ```` ```tokens ```` and closes with ```` ``` ````.
- One `key: value` per line. Keys are lowercase.
- **Read by the hooks:** `font-families` (comma-separated; any other family is flagged),
  `icon-pack` (any other pack is flagged), `spacing-scale` (px numbers; off-scale spacing is
  flagged). Leave a key out to fall back to the generic rules.
- **Read by people and agents:** `personality`, `type-scale`, `palette`, `radius`, `shadows`.

## Writing it

1. Settle the personality first (`choosing-a-website-personality`), with a one-line reason.
2. Derive each token from the personality table, then write the block.
3. Mirror the tokens into code once — `:root` custom properties, the Tailwind theme, or a CSS-in-JS
   theme — and use only those in components.
4. When the design changes, update DESIGN.md in the same change, so the hooks check against the
   current decisions.
