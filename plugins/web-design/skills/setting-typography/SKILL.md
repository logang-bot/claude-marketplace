---
name: setting-typography
description: Sets web typography — choosing one or two proven typefaces for the website personality, a predefined type scale, body text of 16–32px (20px+ for long reads), weights of 400 or more, lines under 75 characters, line-height 1.5–2, and no justified or long centred text. Use when choosing fonts, writing font-size, font-weight, line-height, letter-spacing or text-align in CSS, Tailwind or CSS-in-JS, or styling headings and paragraphs.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Typography

## Rules: Typography (TYPO)
1. Use good, popular typefaces and play it safe.
2. One typeface per page is fine; two at most.
3. Choose the typeface from the website personality.
4. Limit font sizes to a predefined type scale.
5. Normal text: 16–32px.
6. Long text (articles, blog posts): 20px or more.
7. Headlines can go big (50px+) and bold (600+), depending on personality.
8. Never use a font-weight below 400 for any text.
9. Keep lines under 75 characters.
10. Line-height 1.5–2 for normal text; below 1.5 for big text.
11. Tighten letter-spacing on big headlines if it looks loose.
12. Short titles can be all caps: small, bold, with wider letter-spacing.
13. Don't justify text.
14. Don't centre long text blocks; short ones are fine.

## Applying it

- **Define the scale once** as custom properties or theme tokens and use only those sizes. A good
  default (px): 12 / 14 / 16 / 18 / 20 / 24 / 30 / 36 / 44 / 52 / 62 / 74 / 86 / 98. See
  [references/type-scale.md](references/type-scale.md). Tailwind's default `text-*` scale counts
  as a scale; one-off `text-[15px]` values do not.
- **Measure:** `max-width: 65ch` (or 60–70ch) on paragraphs and article bodies.
- **Weights:** 400 regular for body, 500–700 for emphasis and headings. A "light" look comes from
  the typeface, not from weight 300.
- **Line-height:** unitless (`line-height: 1.6`) so it scales with the size; headings around
  1.05–1.25.
- **Letter-spacing:** headlines often want `-0.5px` to `-2px`; all-caps labels want `0.75px`+.
- **Alignment:** left for anything longer than ~3 lines. Centre only short hero or section intros.
- **Loading fonts:** load only the weights you use; `font-display: swap`.

## What the hook checks

`TYPO-02` more than two families (or one not in DESIGN.md), `TYPO-04` a font-size off DESIGN.md's
`type-scale` (or, with no scale there, more than 12 distinct sizes in a file), `TYPO-05` body-text sizes under 16px, `TYPO-08` weights under 400 (including
`font-light`/`fontWeight: 300`), `TYPO-09` text measure over ~75 characters, `TYPO-10`
line-height outside 1.5–2 on body text, `TYPO-13` justified text. The rest is judgement. A custom
style can relax any of these in DESIGN.md except `TYPO-05`.
