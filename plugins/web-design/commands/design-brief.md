---
name: design-brief
description: Creates or updates DESIGN.md, the project's design brief — the website personality (one of seven, or a custom one when none fits) and the tokens (typefaces, type scale, palette, spacing scale, radius, shadows, icon pack, relaxed rules) that the web-design hooks lint against. Use when starting a website design, choosing a personality, recording an existing project's style, or changing design tokens.
argument-hint: "[personality | custom | \"description of the style\"]"
---

Create or update the design brief for this project. `$ARGUMENTS` may be:

- a personality slug: serious-elegant, minimalist-simple, plain-neutral, bold-confident,
  calm-peaceful, startup-upbeat, playful-fun
- `custom`, or a free description of the style ("neo-brutalist, mono type, hard shadows")
- nothing, in which case you choose

The seven personalities are starting points, not a boundary. When the style the user wants, or the
style an existing project already has, fits none of them, write a custom personality instead of
forcing the nearest one.

1. Look for `DESIGN.md` at the project root.
   - **It exists:** read it, say which personality and tokens it records, and ask the user what
     should change. Edit only what changes.
   - **It does not:** continue with step 2.
2. Work out the purpose and audience from the codebase (README, existing pages, package.json).
   Ask the user only what you cannot infer: what the site is for, who it is for, and the feeling
   they want. Use one short question round at most.
3. Settle the personality with the `choosing-a-website-personality` skill:
   - **The user named one of the seven:** use it, and say so if it fits the audience poorly.
   - **The user described a style:** if it matches one of the seven (or a blend), say which; if it
     matches none, it is custom. Do not force it into the nearest one.
   - **Nothing named:** recommend one of the seven with a one-line reason, or custom if none fits.
   - **Existing project:** compare the design already in the code with the seven. When none fits,
     record it as custom and describe what is there, not what it should be.
4. Derive the tokens:
   - **One of the seven:** from that personality's row in the skill's reference: typefaces (one,
     or two at most), type scale, main colour plus grey with tints and shades, spacing scale,
     radius, shadows (or none), icon pack.
   - **Custom:** write the ingredient table first (typography, colour, images, icons, shadows,
     border-radius, layout), then the tokens from it.
   - **Existing project:** take the tokens from the code — the families, radii, spacing and font
     sizes actually in use, rounded to a sensible scale. Running the plugin's `scripts/audit.sh`
     (glob `**/web-design/scripts/audit.sh`) on the project shows which values are in use and
     which rules the current style breaks.
5. **Relaxed rules.** If the style deliberately breaks guideline rules (hard black shadows,
   justified columns, pure black text...), propose a `relax` list with one reason per rule and
   confirm it with the user. Only rules broken on purpose belong there. `COLOR-11` (contrast) and
   `TYPO-05` (body-text size) cannot be relaxed; if the style breaks them, say so plainly.
6. Write `DESIGN.md` in the format of the `writing-a-design-brief` skill, including the fenced
   `tokens` block that the hooks read, and the ingredient table and `## Relaxed rules` section
   for a custom style.
7. If the project already has stylesheets or a Tailwind or theme config, offer to mirror the
   tokens there (`:root` custom properties, `theme.extend`, or the theme object). Do not
   restyle existing pages unless the user asks.

Finish with a short summary: the personality (or the custom label), the typeface(s) and main
colour, the icon pack, and any relaxed rules.
