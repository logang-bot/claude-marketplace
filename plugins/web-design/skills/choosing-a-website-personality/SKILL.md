---
name: choosing-a-website-personality
description: Picks one of seven website personalities (serious/elegant, minimalist/simple, plain/neutral, bold/confident, calm/peaceful, startup/upbeat, playful/fun) from the product, audience and industry — or defines a custom one when none fits, including for an existing project with its own style — then derives every design choice from it — typeface, colour, imagery, icons, shadows, border-radius and layout. Use before designing or restyling any website, landing page, or web app screen, when the user asks for a look or feel, or when DESIGN.md is missing or its personality no longer fits.
---

# Website personality

Design ingredients are applied differently for different personalities, so the personality is
decided **first** and every later choice is checked against it. Record it in `DESIGN.md` (see the
`writing-a-design-brief` skill) so later work and the hooks use the same one.

## Rules: Personality (PERS)
1. Serious/Elegant — luxury: thin serif type, gold or pastel colours, big quality images.
2. Minimalist/Simple — text first: small black sans-serif, lines, few images or icons.
3. Plain/Neutral — neutral small type, very structured layout; big corporations.
4. Bold/Confident — big bold type, big blocks of bright colour.
5. Calm/Peaceful — pastels, soft serif headings, matching images or illustrations.
6. Startup/Upbeat — medium sans-serif, light-grey text and backgrounds, rounded elements.
7. Playful/Fun — colourful, round, hand-drawn art, animation, fun words.
8. Custom — none fits: define the style by its ingredients in DESIGN.md.

## Choosing

1. Ask, or infer from the request: what is the product, who is it for, and what should a visitor
   feel in the first five seconds? Industry is a strong hint (table below), not a rule.
2. Pick **one** primary personality. A secondary flavour is fine ("startup with a calm palette"),
   but name which one wins when they disagree.
3. Write the derived choices down before writing markup: typeface(s), main colour plus greys,
   icon pack, shadow and radius policy, image style, layout pattern.
4. When there is no DESIGN.md and the work builds new pages or screens, ask the user first: create
   the brief with `/design-brief`, or let you decide. If they let you decide, or the change is
   small, propose a personality with a one-line reason and continue. Do not stall on it.

| Personality | Typical industries |
|---|---|
| Serious/Elegant | real estate, high fashion, jewellery, luxury products and services |
| Minimalist/Simple | fashion, portfolios, minimalist brands, writing-first sites |
| Plain/Neutral | big corporations, government, institutions |
| Bold/Confident | digital agencies, software startups, travel, "strong" brands |
| Calm/Peaceful | healthcare, wellness, consumer products that care |
| Startup/Upbeat | software startups, SaaS, modern tech companies |
| Playful/Fun | children's products, pets, food, games |

The full ingredient-by-ingredient table for each personality — typefaces to start from, palette
direction, imagery, icons, shadows, radius, layout — is in
[references/personalities.md](references/personalities.md). Read it when writing the brief.

## When none fits

The seven are starting points, not a boundary. Use them in this order:

1. **One of the seven**, when it fits.
2. **A blend**, when two fit: name the primary and the secondary ("startup, with a calm palette")
   and say which wins where they disagree.
3. **Custom**, when none fits — a style the user describes (neo-brutalist, Swiss/International,
   retro-terminal, luxury editorial...), or an existing project whose design matches none of them.
   Never force the nearest personality onto it.

A custom personality is written into DESIGN.md as `personality: custom — <short label>`, with a
`## Personality` section that defines it by the same ingredients the seven use: typography,
colour, images, icons, shadows, border-radius, layout. For an existing project, describe what the
code already does — the families, colours, radii and spacing actually in use — not what it should
do. The tokens then come from that description, and the hooks check against them like any other
brief.

A custom style may deliberately break some of the guideline rules: opaque black shadows in
neo-brutalism, justified columns in an editorial layout, pure black text on a stark minimal site.
List those rules in the brief's `relax` token with a one-line reason each (see the
`writing-a-design-brief` skill), and the linter stops reporting them. Only rules the style breaks
on purpose belong there, not ones the code breaks by accident.

## Rules that never bend

Two rules hold whatever the style and cannot be relaxed: text contrast stays at 4.5:1 (3:1 for
large text) and body text stays 16px or larger. Everything else is the default for the seven
personalities. Weight 400 or above is one of them: a Serious/Elegant site gets its "thin" look
from a light serif at weight 400, not from weight 200. A custom style may relax a default, but
only in DESIGN.md and with a reason.
