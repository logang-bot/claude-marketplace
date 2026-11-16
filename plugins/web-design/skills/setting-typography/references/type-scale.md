# Type scale

A type scale is a short, fixed list of font sizes. Every `font-size` in the project comes from it.

## Default scale (px)

```
12  14  16  18  20  24  30  36  44  52  62  74  86  98
```

As custom properties, in rem against the browser's default 16px root:

```css
:root {
  --fs-12: 0.75rem;  --fs-14: 0.875rem; --fs-16: 1rem;     --fs-18: 1.125rem;
  --fs-20: 1.25rem;  --fs-24: 1.5rem;   --fs-30: 1.875rem; --fs-36: 2.25rem;
  --fs-44: 2.75rem;  --fs-52: 3.25rem;  --fs-62: 3.875rem; --fs-74: 4.625rem;
  --fs-86: 5.375rem; --fs-98: 6.125rem;
}
```

With `html { font-size: 62.5%; }` the root is 10px and 1rem = 10px, so 16px is `1.6rem`.

## Picking sizes from it

| Role | Typical size |
|---|---|
| Fine print, labels, eyebrows (all caps) | 12–14 |
| Body text | 16–20 |
| Long-form article body | 20–24 |
| Sub-headings | 24–36 |
| Section headings | 36–52 |
| Hero headline | 52–98 |

Generated alternatives: a modular scale (ratio 1.25 "major third" or 1.333 "perfect fourth") from
16px. Tools: typescale.com, type-scale.com.
