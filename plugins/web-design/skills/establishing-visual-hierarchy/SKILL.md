---
name: establishing-visual-hierarchy
description: Establishes visual hierarchy on web pages — important things near the top, images used mindfully, whitespace for emphasis, importance conveyed through size, weight, colour and spacing, and components emphasised with background, shadow or border or by de-emphasising their neighbours. Use when laying out a page or section, styling headings, CTAs, pricing tables, testimonials or cards, or when everything on a page competes for attention.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Visual hierarchy

## Rules: Visual hierarchy (HIER)
1. Put important elements near the top of the page, where they get attention.
2. Use images mindfully; larger images draw more attention.
3. Whitespace separates, so use it strategically to emphasise.
4. Convey text importance with size, weight, colour and whitespace.
5. Emphasise titles, sub-titles, links, buttons, data points and icons.
6. Emphasise a component with background colour, shadow or border (or several).
7. Emphasise A over B by de-emphasising B.
8. Emphasise testimonials, CTA sections, highlights, preview cards, forms, pricing tables, key table rows and columns.

## Applying it

- **Decide the order first.** For each section, name the one thing a visitor must see first, then
  second, then third. Style in that order; if two things are equally loud, one is wrong.
- **Text levels:** limit to about four — heading, sub-heading, body, muted/meta. Separate them
  with at least two of: size step, weight step (400 → 600/700), colour step (heading dark, body
  grey, meta lighter grey), spacing.
- **De-emphasise rather than shout:** make secondary buttons outline or text-only, metadata grey
  and smaller, instead of making the primary button bigger and bigger.
- **Components:** a featured pricing tier gets the main-colour border or background plus a
  shadow; the others stay plain. One emphasised component per section.
- **Images vs CTA:** a large hero image will out-pull the CTA; balance it with a darker overlay,
  a smaller image, or a high-contrast button in the main colour.

Nothing here is machine-checkable; the `design-reviewer` agent reviews hierarchy.
