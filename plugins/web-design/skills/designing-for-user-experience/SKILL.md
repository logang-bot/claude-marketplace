---
name: designing-for-user-experience
description: Applies web UX rules — familiar layout patterns, the call-to-action as the most prominent element with descriptive text, blue and underlined text only for links, purposeful 200–500ms animations, single-column forms, feedback for every action, buttons near their effect, a descriptive keyword-focused headline, and short, plain, scannable copy. Use when building navigation, CTAs, forms, buttons, transitions or animations, or writing headlines and on-page copy.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# User experience

## Rules: User experience (UX)
1. Don't design complicated layouts; reuse patterns users already know.
2. Make the call-to-action the most prominent element, with descriptive text.
3. Use blue text and underlined text only for links.
4. Animations need a purpose and should be fast: 200–500ms.
5. In forms, align labels and fields in one vertical line.
6. Give feedback for every action: form errors, success, etc. (web apps)
7. Place action buttons where they take effect (law of locality). (web apps)
8. Main-page headline: descriptive and keyword-focused, never vague or fancy.
9. Include only relevant information; cut the fluff.
10. Use simple words; avoid jargon and "smart-sounding" words.
11. Break up long text with sub-headings, images, block quotes and bullet points.

## Applying it

- **CTA text says what happens:** "Start your free trial", "Book a demo", "Get the guide" — not
  "Submit", "Click here", "Learn more" on its own. One primary CTA per view.
- **Links:** if a non-link is blue or underlined, users will click it. Use bold, colour shades or
  backgrounds for emphasis instead.
- **Animation timing:** `transition: transform 250ms ease-out`. Hover feedback 200–300ms, larger
  movements up to 500ms. Respect `@media (prefers-reduced-motion: reduce)`. Looping loaders are
  exempt from the time limit, not from having a purpose.
- **Forms:** label above field, one column, full-width inputs on mobile, inline error messages next
  to the field they belong to, a visible success state.
- **Headline test:** a stranger reading only the hero headline can say what the product is and
  who it is for. "Accounting software for freelancers" beats "Unleash your potential".
- **Copy:** short paragraphs (2–4 lines), sub-headings every few paragraphs, bullet lists for
  three or more parallel items.

## What the hook checks

`UX-02` vague button/link text ("click here", "submit", "here", "go", "ok"), `UX-03` underlines
on non-link selectors, `UX-04` transition/animation durations outside 200–500ms (infinite loops
exempt). Copy quality, headlines, form layout and feedback states are the `ux-reviewer` agent's.
