---
name: creating-composables
description: When creating a new function that is marked as composable
paths: "**/*.kt"
---

When creating a composable, take into consideration these guidelines:

1. **Always put `Modifier` as the first optional parameter**: If a `Modifier` parameter is needed, it must always be the first optional parameter. Pass it down to the root composable element.
2. **Split into child composables**: There is no strict size limit on a composable function, but prefer splitting into smaller, focused child composables for readability and reuse.
3. **Identify business logic**: If you identify business logic inside a composable, move it out of the composable. Use a ViewModel for UI state management, or a UseCase for domain logic. See `identifying-use-cases` for guidance on when a UseCase is appropriate.
