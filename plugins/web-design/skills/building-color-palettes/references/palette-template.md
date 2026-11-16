# Palette template

Replace the hex values with the tints and shades of your own main colour and grey. Keep the
names; components should only ever reference these.

```css
:root {
  /* main colour: tints (lighter) → base → shades (darker) */
  --primary-50:  #eef2ff;
  --primary-100: #e0e7ff;
  --primary-200: #c7d2fe;
  --primary-300: #a5b4fc;
  --primary-400: #818cf8;
  --primary-500: #6366f1;   /* base */
  --primary-600: #4f46e5;
  --primary-700: #4338ca;
  --primary-800: #3730a3;
  --primary-900: #312e81;

  /* greys, slightly tinted toward the main colour */
  --grey-50:  #f8fafc;
  --grey-100: #f1f5f9;
  --grey-200: #e2e8f0;
  --grey-300: #cbd5e1;
  --grey-500: #64748b;
  --grey-700: #334155;   /* body text on white: 10.3:1 */
  --grey-900: #0f172a;   /* headings — dark, not pure black */

  /* roles */
  --color-text: var(--grey-700);
  --color-heading: var(--grey-900);
  --color-muted: var(--grey-500);      /* 4.76:1 on white — the lightest text allowed */
  --color-bg: #ffffff;
  --color-surface: var(--grey-50);
  --color-border: var(--grey-200);
  --color-accent: var(--primary-600);
}
```

Dark section: background `--primary-900`, text `--primary-100` (a tint of the background).
