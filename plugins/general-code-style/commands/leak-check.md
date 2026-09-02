---
name: leak-check
description: Finds and fixes leaked resources — unreleased handles, missing cleanup on error paths, subscriptions that outlive their owner, unbounded caches, retention through statics, ownership cycles — using the leak-hunter agent. Use when investigating growing memory or handle counts, or after writing code that acquires a resource. Pass --report-only to review without editing.
argument-hint: "[path] [--report-only]"
---

Hunt for leaked resources in `$ARGUMENTS`.

**This command edits code unless `--report-only` is passed.** Say so in one line before you
start, together with the target you picked, so the user can stop you if the tree is not in a
state to be changed.

## Picking a target

Count the source files first — `git ls-files <path>` in a repo, otherwise a directory listing.

- **No path** → the uncommitted working tree.
- **30 files or fewer** → the path as given.
- **More than 30 files** → do not run over all of it. Tracing a lifecycle means reading every
  path out of a scope, so a target that size exhausts the agent's context before it finishes.
  Say how many files the target holds and ask which module or entry point to start from.

## Running it

Launch the `leak-hunter` agent against the target, or tell it to review the uncommitted working
tree (`git diff --name-only HEAD` plus `git ls-files --others --exclude-standard`) if no path
was given.

If `--report-only` was passed, tell the agent explicitly to report without editing anything.
Use that mode when the tree already holds uncommitted work, or on code you do not own.

## Afterwards

Relay both of the agent's lists — what it fixed, and what it found but did not fix — along with
its test result, unchanged.

Then show the diff for the files it touched and stop. Every edit here changes a lifecycle —
exactly the kind of change that passes review by looking small — so the diff is the report.
Where the agent left a finding unfixed because it needs a design change, that is the next
conversation rather than the next edit.
