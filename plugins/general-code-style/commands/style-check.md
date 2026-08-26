---
name: style-check
description: Review code against the file, function, parameter, and naming style rules
argument-hint: [path]
---

Launch the `style-reviewer` agent against `$ARGUMENTS`.

If `$ARGUMENTS` is empty, tell the agent to review the uncommitted working tree instead.

Relay the agent's findings to the user grouped by file, most severe first. Do not apply any
fixes unless the user asks for them after seeing the report.
