---
name: style-check
description: Review code against the file, function, parameter, naming, and comment style rules
argument-hint: [path] [--sweep]
---

Check `$ARGUMENTS` against the style rules. Pick the mode from the size of what you are
pointed at, and always tell the user which mode you used and what it did not cover.

## Picking a mode

Count the source files in the target first — `git ls-files <path>` in a repo, otherwise a
directory listing.

- **No path** → agent review of the uncommitted working tree.
- **30 files or fewer** → agent review of the path.
- **More than 30 files** → sweep. An agent cannot read a codebase that size without
  exhausting its context, and reading is what costs.
- **`--sweep` present** → sweep, whatever the size.

Say which mode you picked and why in one line before you run it.

## Agent review

Launch the `style-reviewer` agent against the path, or tell it to review the uncommitted
working tree (`git diff --name-only HEAD` plus `git ls-files --others --exclude-standard`) if
no path was given. It covers all five rules and is read-only.

Relay its findings grouped by file, most severe first.

## Sweep

Locate `scripts/sweep.py` inside this plugin by globbing for
`**/general-code-style/scripts/sweep.py` rather than assuming an install path, then run it:

```
python3 <path-to>/sweep.py <target> --top 20
```

Print the report as it comes back. Do not re-rank it, re-summarise it, or re-measure anything
yourself — it is already ordered by severity and capped, and it reads its limits from the same
file the size hook uses.

Then state plainly, in one line, that the sweep covered the size and parameter rules only, and
that naming and comment discipline were **not** evaluated because those need a reading of the
code rather than a measurement of it.

Finally, offer the next step and stop: ask whether to review one of the listed files with the
`style-reviewer` agent, which does cover the remaining two rules.

## In both modes

Do not apply fixes. Report, then wait to be asked.

If the user asks for fixes afterwards, work **one file at a time** and show what changed. Never
rewrite a batch of files from a sweep in one pass — the sweep is a worklist, not a task queue.
