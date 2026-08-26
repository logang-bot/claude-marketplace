---
name: changelog
description: Append a user-facing change to the unreleased changelog scratchpad
argument-hint: <what changed>
---

Append `$ARGUMENTS` as a bullet to the pending section of `CHANGELOG.unreleased.md`. If this
project names its changelog files differently, find them first rather than assuming.

If `$ARGUMENTS` is empty, look at the uncommitted working tree (`git diff`, plus untracked
files) and propose a bullet describing what changed, for the user to confirm before you write
it.

Rules:
- One short bullet. Developer-facing English is fine — this file is a scratchpad, not the
  release notes.
- **Do not touch `CHANGELOG.md`.** That file changes only at release time, via `/ship`.
- Skip changes with no user or security impact: internal refactors, docs, tests, tooling. If
  what you were given is one of those, say so and write nothing.
- If the file or its pending section does not exist, create it in the shape the project's
  other changelog file already uses.

Confirm in one line what you appended.
