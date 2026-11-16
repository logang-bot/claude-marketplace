---
name: using-images-and-illustrations
description: Chooses and places website imagery — relevant, original-looking photos, illustrations and patterns that support the message, real people for emotion, three safe ways to put text over an image, 2x resolution, compression, and identical dimensions for side-by-side images. Use when adding hero images, product shots, illustrations, backgrounds, galleries or <img>/background-image markup and CSS.
paths: "**/*.css,**/*.scss,**/*.less,**/*.html,**/*.htm,**/*.vue,**/*.svelte,**/*.astro,**/*.jsx,**/*.tsx"
---

# Images and illustrations

## Rules: Images (IMG)
1. Kinds: product photos, storytelling photos, illustrations, patterns.
2. Use only images that support the site's message and story.
3. Prefer original images; else original-looking stock, never generic.
4. Show real people to trigger emotion.
5. Crop images to fit the message.
6. Experiment with combining photos, illustrations and patterns.
7. Text on an image, method 1: darken or brighten it (fully or via a gradient).
8. Method 2: place the text in a neutral area of the image.
9. Method 3: put the text in a box.
10. Serve images at 2x their displayed size for high-res screens.
11. Compress images for size and speed.
12. Side-by-side images must have exactly the same dimensions.

## Applying it

- **Text over images** (rules 7–9), in CSS:
  ```css
  .hero {
    background-image: linear-gradient(rgba(34, 34, 34, 0.6), rgba(34, 34, 34, 0.6)), url(hero.jpg);
    background-size: cover;
  }
  ```
  or a box: `.hero__text { background: rgba(255,255,255,.9); padding: 32px; }`. Check the text
  contrast against the darkened image, not against the raw photo.
- **Resolution and size** (10–11): a 600px-wide slot gets a 1200px source; use `srcset`/`sizes`
  or `<picture>` with WebP/AVIF, and compress (Squoosh, TinyPNG). Always set `width` and `height`
  attributes so the layout does not shift, plus `loading="lazy"` below the fold.
- **Side by side** (12): give grids of images one aspect ratio with `aspect-ratio` +
  `object-fit: cover`, and matching `width`/`height` attributes.
- **Placeholders** while building: use neutral placeholders (`https://placehold.co/1200x800`) and
  say in the hand-back which images are placeholders — never present generic stock as final.
- **Alt text:** describe what the image contributes; `alt=""` for decorative images.

## What the hook checks

`IMG-12` neighbouring `<img>` elements whose `width`/`height` attributes differ (small icon-sized
images are ignored). Relevance, originality, cropping and text legibility over images need the
`design-reviewer` agent.
