---
name: design-brief
description: Creates or updates DESIGN.md, the project's design brief — the website personality and the tokens (typefaces, type scale, palette, spacing scale, radius, shadows, icon pack) that the web-design hooks lint against. Use when starting a website design, choosing a personality, or changing design tokens.
argument-hint: "[personality]"
---

Create or update the design brief for this project. `$ARGUMENTS` may name a personality
(serious-elegant, minimalist-simple, plain-neutral, bold-confident, calm-peaceful, startup-upbeat,
playful-fun). If it does not, choose one.

1. Look for `DESIGN.md` at the project root.
   - **It exists:** read it, say which personality and tokens it records, and ask the user what
     should change. Edit only what changes.
   - **It does not:** continue with step 2.
2. Work out the purpose and audience from the codebase (README, existing pages, package.json).
   Ask the user only what you cannot infer: what the site is for, who it is for, and the feeling
   they want. Use one short question round at most.
3. Use the `choosing-a-website-personality` skill to recommend one personality, with a one-line
   reason. If the user named one, use it, and say so if it fits the audience poorly.
4. Derive the tokens from that personality's row in the skill's reference: typefaces (one, or
   two at most), type scale, main colour plus grey with tints and shades, spacing scale, radius,
   shadows (or none), icon pack.
5. Write `DESIGN.md` in the format of the `writing-a-design-brief` skill, including the fenced
   `tokens` block that the hooks read.
6. If the project already has stylesheets or a Tailwind or theme config, offer to mirror the
   tokens there (`:root` custom properties, `theme.extend`, or the theme object). Do not
   restyle existing pages unless the user asks.

Finish with a three-line summary: the personality, the typeface(s) and main colour, and the icon
pack.
