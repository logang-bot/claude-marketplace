---
name: creating-or-update-new-screen-routes
description: When creating or updating screen routes in any navigation composable
paths: "**/*.kt"
---

When creating a new route or updating an existing one, follow these guidelines:

1. **Initialize ViewModels inside the screen, not in the navigation file**: Every screen is responsible for creating its own ViewModels. The navigation composable must only pass primitive arguments (IDs, flags) — never ViewModel instances.
2. **Keep state and effect logic inside the screen**: `LaunchedEffect`, `remember`, and any other state initialization must live inside the screen composable, not in the navigation file.