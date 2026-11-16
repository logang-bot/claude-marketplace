# Components and layout patterns

## Elements

Text (headings, paragraphs, lists), buttons (primary, secondary/outline, text), links, images,
icons, inputs (text, select, checkbox, radio, toggle), badges/tags, avatars, dividers.

## Components

| Component | Use it for | Notes |
|---|---|---|
| Navigation bar | Site-wide wayfinding | Logo left, ≤ 6 links, one CTA button right; collapses to a menu button on mobile |
| Hero | The first screen: what, for whom, primary CTA | Headline + sub-headline + CTA + image/product shot |
| Breadcrumbs | Deep content hierarchies | Not needed on landing pages |
| Pagination | Long lists split into pages | Show current page, prev/next |
| Feature block | One benefit: icon + title + 1–2 lines | Used in a grid of 3–4 |
| Card / preview card | A summary that links to more | Image, title, meta, short text; whole card clickable |
| Testimonial | Social proof | Quote, real name, photo, role; emphasise with a background |
| Logo cloud | "Trusted by" proof | Greyscale logos, one row |
| Stats / data points | Proof with numbers | Big number, small label |
| Pricing table | Plan comparison | 2–4 tiers, one emphasised, feature list, CTA per tier |
| Accordion | FAQ, long optional detail | One open at a time is fine; whole header is the toggle |
| Tabs | Parallel content of equal weight | 2–5 tabs; never for sequential steps |
| Carousel | Several items of equal weight in little space | Visible controls, no auto-play for text |
| Table | Structured comparison | Emphasise the key row or column |
| Form | Signup, contact, checkout | One column, labels above, inline errors |
| Modal | Focused task over the page | Large shadow, overlay, close button, Esc closes |
| Call-to-action section | Final push before the footer | Main-colour background, one button |
| Footer | Secondary navigation, legal, contact | Multi-column links, muted colours |

## Layout patterns

| Pattern | Shape | Good for |
|---|---|---|
| Row of boxes / cards | 3–4 equal columns | Features, testimonials, blog previews |
| Grid of boxes / cards | Repeating rows of equal cards | Products, galleries, team |
| Nested grid | A big item beside a grid of small ones | Featured post + others, bento sections |
| Z-pattern | Eye moves left→right, diagonal, left→right | Simple landing pages with little copy |
| F-pattern | Scanning down the left edge, reading the top lines | Text-heavy pages, articles, search results |
| Single column | One centred column | Articles, forms, minimalist sites |
| Sidebar | Narrow column beside content | Docs, dashboards, blogs |
| Multi-column / magazine | Several content columns of different widths | Content-rich, editorial |
| Asymmetry / experimental | Deliberately uneven weights | Bold, playful or editorial personalities; use sparingly |
| Alternating split | Image and text swap sides each row | "How it works", feature deep-dives |

## A complete landing page, assembled

```
header  nav: logo · links · CTA
main
  hero            split: headline + sub + CTA | product image
  logo cloud      row
  features        row of 3 feature blocks
  how it works    alternating split ×3
  testimonials    row of 3 cards (emphasised background)
  pricing         row of 3 tiers, middle one emphasised
  faq             accordion, single column
  cta section     centred, main-colour background
footer  multi-column links · legal
```
