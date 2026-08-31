---
name: creating-or-updating-screen-routes
description: Keeps Compose navigation graphs thin — each screen creates its own ViewModels, the route passes only primitive arguments such as IDs and flags, and LaunchedEffect and remember stay inside the screen composable. Use when adding or editing a route, working in a NavHost or navigation composable, or wiring a screen into navigation. Applies however the file was written — including one created by a shell command or another tool rather than the file editor, and one written while carrying out an already-approved plan.
paths: "**/*.kt"
---

When creating a new route or updating an existing one, follow these guidelines:

1. **Initialize ViewModels inside the screen, not in the navigation file**: Every screen is responsible for creating its own ViewModels. The navigation composable must only pass primitive arguments (IDs, flags) — never ViewModel instances.
2. **Keep state and effect logic inside the screen**: `LaunchedEffect`, `remember`, and any other state initialization must live inside the screen composable, not in the navigation file.