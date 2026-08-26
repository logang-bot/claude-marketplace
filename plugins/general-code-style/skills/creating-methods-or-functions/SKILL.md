---
name: creating-methods-or-functions
description: When creating new methods or functions follow the guidelines described here
---

When creating a method or function, take into consideration these guidelines:

1. **Keep it short**: Limit the method body to ~7 lines (with a maximum of +3 lines spare).
2. **Limit the number of parameters**: Allow a maximum of three parameters. If more are needed, group the related extras into a data class (or the equivalent record/struct/interface in the language at hand).
3. **Group parameters semantically**: When creating a type to hold parameters, group only fields that are genuinely related to each other.
4. **Make the name explain the purpose**: Since each method is small, its name must make the intent obvious. If a reader needs prose to follow the body, the names are wrong or the method is doing too much — rename it or split it.
5. **Never explain code with inline comments**: Do not narrate a flow, label steps, or restate what a line does. The only text allowed inside a body is text that is not explanation: tool directives (`// noinspection`, `// eslint-disable-next-line`, `#pragma`), `TODO`/`FIXME` markers, and file header or licence banners.
6. **Document only non-obvious math or algorithms**: When a body implements a formula, numeric method, or algorithm whose correctness is not evident from the code, document it in the platform's own doc-comment form — `/// <summary>` in C#, KDoc in Kotlin, JSDoc in TS/JS, a docstring in Python — placed above the declaration. Never inline, and never on a member whose name already says it.

**Exception — UI component functions.** Functions that declare UI in a component-based
framework (Jetpack Compose composables, React components, SwiftUI views) are exempt from the
body-length and parameter-count limits above, and from those only — the comment rules apply to
them like anywhere else. They routinely take many optional configuration parameters and read
top-down as markup rather than as procedural logic. Follow the rules of the platform plugin for
that framework instead, if one is installed.
