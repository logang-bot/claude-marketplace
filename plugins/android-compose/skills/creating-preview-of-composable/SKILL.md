---
name: creating-preview-of-composable
description: When creating a preview for a composable take into account the guidelines described here
paths: "**/*.kt"
---

When creating a new preview composable, follow these guidelines:

1. **Place it in the same file as the target composable**: The preview function must always live in the same file as the composable it previews.
2. **Create variants for light and dark mode**: Every preview must include two `@Preview`-annotated functions — one with `uiMode = Configuration.UI_MODE_NIGHT_NO` (light) and one with `uiMode = Configuration.UI_MODE_NIGHT_YES` (dark). Skip dark mode only when the composable explicitly does not support theming (e.g., a pure layout with no color references).
3. **Name previews clearly**: Use the pattern `<ComposableName>Preview` for the light variant and `<ComposableName>DarkPreview` for the dark variant.