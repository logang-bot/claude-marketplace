---
name: design-review
description: Reviews code for design antipatterns and architectural problems — cohesion, coupling, dependency direction, leaky abstractions, testability, error handling — using the senior-reviewer agent. Use when asked for a design or architecture review, after a feature lands, or before starting a refactor.
argument-hint: "[path]"
---

Review the design of `$ARGUMENTS`. This covers structure, not style — `/style-check` owns size,
naming, and comments, and this command does not repeat them.

## Picking a target

Count the source files first — `git ls-files <path>` in a repo, otherwise a directory listing.

- **No path** → the uncommitted working tree.
- **30 files or fewer** → the path as given.
- **More than 30 files** → do not run. There is no mechanical fallback here the way
  `/style-check` has a sweep, because every finding needs the code read and its callers read
  with it. Say how many files the target holds and ask which module, layer, or feature to
  review instead.

Say which target you picked in one line before you run it.

## The review

Launch the `senior-reviewer` agent against the path, or tell it to review the uncommitted
working tree (`git diff --name-only HEAD` plus `git ls-files --others --exclude-standard`) if
no path was given. It is read-only.

Relay its findings in the order it gave them, keeping its split between **structural** findings
and **judgement** calls. Do not promote a judgement call into a defect to make the report look
firmer, and do not add findings of your own on top of it.

## Afterwards

Do not apply fixes. Report, then wait to be asked.

A design finding is a refactor rather than an edit. If the user asks for one, take a single
finding at a time and agree the restructuring before touching the code — the fixes in a design
report are rarely independent of each other.
