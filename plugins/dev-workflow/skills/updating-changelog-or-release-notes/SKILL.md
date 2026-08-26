---
name: updating-changelog-or-release-notes
description: When adding a changelog entry, recording a user-facing change, bumping the version, or preparing a release — always read the unreleased scratchpad first.
---

This plugin assumes **two changelog files** with different audiences. Create them in this
shape if the project has only one, or none:

- **`CHANGELOG.unreleased.md`** — a developer-facing scratchpad of changes that have landed
  but are not yet shipped. Appended to continuously, during normal development.
- **`CHANGELOG.md`** — the curated, customer-facing release notes. One `## [VERSION]` section
  per shipped version. Written **only at release time**, never per-change.

If this project uses different filenames, find them before assuming — but keep the same
split of roles.

## Read the project's own settings first

Before writing release notes, find where this project documents its release process. Look in
this order: the project's `CLAUDE.md`, then a release or shipping document under `docs/`, then
the header of the changelog files themselves — many projects document their own conventions
there. You need four things:

- **where the version constant lives** (the build file, a manifest, a package file) — the
  release pipeline usually requires the changelog section header to match it exactly
- **the language and audience** of `CHANGELOG.md` — it is not always English, and not always
  written for developers
- **any length limit** — some pipelines forward release notes to a channel with a hard cap
- **pre-release steps** — migrations, functions, or services that must be deployed before the
  release goes out

If none of those say, ask rather than guessing. Getting the version header wrong typically
fails the release build.

## When a user-facing change lands (normal development)

Append a short bullet to the pending list in `CHANGELOG.unreleased.md`. Developer-facing
English is fine here.

**Do not edit `CHANGELOG.md`** for an individual change.

Skip changes with no user or security impact: internal refactors, docs, tests, tooling.

## When preparing a release

1. **Read `CHANGELOG.unreleased.md`** — it holds everything to announce.
2. Decide the new version and set the version constant where the project's docs say it lives.
3. **Distill all pending bullets into ONE new `## [VERSION]` section** at the top of the
   version list in `CHANGELOG.md`, following that file's established house style:
   - Written for the reader those docs name, in the language the changelog already uses.
   - Short phrases describing **what changes for the person using the software** — never file
     names, class names, or technical internals.
   - The section header **must exactly match** the version constant.
   - Respect the length limit if the project has one.
   - If a pending change has no user-visible effect (an internal security fix, say), state
     that plainly rather than inventing a feature.
4. **Reset `CHANGELOG.unreleased.md`** — remove the distilled bullets, leaving the header and
   an empty pending section.

## Boundaries

- **Do not run git commands** — no commit, tag, or push. Stop after the file edits and tell
  the user the version and tag to push. See `no-git-writes`.
- Before a production release, remind the user of any pre-release deployment steps the
  project documents. Skipping them typically breaks the shipped build at runtime, not at
  build time, so it fails silently until a user hits it.
