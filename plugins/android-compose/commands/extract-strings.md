---
name: extract-strings
description: Moves hardcoded user-facing string literals out of Kotlin into strings.xml and rewrites the call sites to stringResource or context.getString. Use when asked to extract, externalise, or localise hardcoded UI strings.
argument-hint: "[path]"
---

Find hardcoded user-facing string literals in `$ARGUMENTS` (or, if empty, in the Kotlin files
changed in the uncommitted working tree) and move them into `strings.xml`.

**Extract** literals that reach the user: labels, button text, titles, messages, content
descriptions, placeholders, error text shown in the UI.

**Leave alone** — these are explicitly exempt:
- exception messages and error identifiers (internal, not user-facing)
- log and debug strings
- technical identifiers: keys, tags, route names, API field names, database column names

For each extraction:
1. Add a `<string>` entry to `strings.xml` with a key named for its meaning and screen, in the
   naming style already used in that file — read it first.
2. Replace the literal with `stringResource(R.string.key)` inside a composable, or
   `context.getString(R.string.key)` elsewhere.
3. Reuse an existing key when one already says the same thing rather than adding a duplicate.

If the project has more than one `strings.xml` (localized variants), add to the default one
only and tell the user which translations now need updating.

Show the user a list of what you extracted and what you deliberately skipped, so they can
check your judgement on the boundary cases.
