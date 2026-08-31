---
name: creating-preview-of-composable
description: Requires Compose @Preview functions to live in the same file as the composable they preview, to come in light and dark uiMode pairs, and to be named <ComposableName>Preview and <ComposableName>DarkPreview. Use when adding or editing a @Preview, or when a newly written composable still has none. Applies however the file was written — including one created by a shell command or another tool rather than the file editor, and one written while carrying out an already-approved plan.
paths: "**/*.kt"
---

When creating a new preview composable, follow these guidelines:

1. **Place it in the same file as the target composable**: The preview function must always live in the same file as the composable it previews.
2. **Create variants for light and dark mode**: Every preview must include two `@Preview`-annotated functions — one with `uiMode = Configuration.UI_MODE_NIGHT_NO` (light) and one with `uiMode = Configuration.UI_MODE_NIGHT_YES` (dark). Skip dark mode only when the composable explicitly does not support theming (e.g., a pure layout with no color references).
3. **Name previews clearly**: Use the pattern `<ComposableName>Preview` for the light variant and `<ComposableName>DarkPreview` for the dark variant.