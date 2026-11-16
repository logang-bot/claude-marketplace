# Spacing scale

```
2  4  8  12  16  24  32  48  64  80  96  128   (px)
```

As custom properties:

```css
:root {
  --space-2: 0.125rem; --space-4: 0.25rem; --space-8: 0.5rem;  --space-12: 0.75rem;
  --space-16: 1rem;    --space-24: 1.5rem; --space-32: 2rem;   --space-48: 3rem;
  --space-64: 4rem;    --space-80: 5rem;   --space-96: 6rem;   --space-128: 8rem;
}
```

Tailwind's default spacing (`p-1` = 4px, `p-2` = 8px, `p-3` = 12px, `p-4` = 16px, `p-6` = 24px,
`p-8` = 32px, `p-12` = 48px, `p-16` = 64px, `p-20` = 80px, `p-24` = 96px, `p-32` = 128px) maps onto
the same steps. Prefer those classes; the in-between ones (`p-5`, `p-7`, `p-9`...) exist, but use
them sparingly.

A stricter alternative from the guidelines: **multiples of 16px only** (16 / 32 / 48 / 64 / 96 /
128), with 4 and 8 for the inside of small components. Record it in DESIGN.md as
`spacing-scale: 4 8 16 32 48 64 96 128`.
