---
name: composing-components-and-layouts
description: Composes web pages from common elements and components (navigation, hero, feature grid, cards, testimonials, pricing, CTA, accordion, tabs, forms, footer) arranged with common layout patterns (row or grid of boxes, Z and F patterns, sidebar, multi-column, asymmetry), then assembles layout areas into a complete page. Use when structuring a new page or section, picking a layout, building reusable components, or turning a brief into a page outline.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Components and layout

## Rules: Components and layout (LAYOUT)
1. Convey the site's information with common elements and components.
2. Combine components into layouts with common layout patterns.
3. Assemble the layout areas into a complete, final page.

## Applying it

Work from the outside in:

1. **Outline the page** as a list of sections, each with one job: hero (what and for whom) →
   social proof → features/benefits → how it works → testimonials → pricing → FAQ → final CTA →
   footer. Drop what the brief does not need (UX-9).
2. **Pick a layout pattern per section** from the catalogue: a hero is usually a two-column
   split or a centred stack, features a grid of boxes, testimonials a row of cards.
3. **Build components** from elements (buttons, inputs, badges, avatars, icons), styled only with
   the DESIGN.md tokens.
4. **Assemble** the page and check the rhythm: alternating section backgrounds, consistent
   container width (~1200px), whitespace tiers from the whitespace skill.

The catalogue of components and patterns, with when to use each, is in
[references/catalogue.md](references/catalogue.md).

Use semantic HTML for the areas: `header`, `nav`, `main`, `section` with a heading, `footer`,
`ul` for card grids, `button` for actions and `a` for navigation. Use CSS Grid for
two-dimensional layouts and Flexbox for one-dimensional rows.

Layout choices are reviewed by the `ux-reviewer` agent; nothing here is machine-checked.
