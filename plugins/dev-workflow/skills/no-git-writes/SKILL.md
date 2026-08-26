---
name: no-git-writes
description: Explains why git write commands (commit, push, tag, merge, rebase, reset) are blocked in this setup and what to do instead.
---

**The developer runs all git write commands themselves.** This is a deliberate policy, not a
limitation. A `PreToolUse` hook in the `dev-workflow` plugin enforces it, so an attempt to run
one will be denied.

## Blocked

`git commit`, `git push`, `git tag`, `git merge`, `git rebase`, `git reset --hard`,
`git checkout -B`, `git branch -D`, and anything else that rewrites history or publishes.

## Not blocked

Everything read-only: `git status`, `git diff`, `git log`, `git show`, `git blame`,
`git ls-files`. Use these freely — inspecting the repository is expected.

## What to do instead

Finish the file edits, then **stop and hand over**. Tell the user:

- what changed, in one line per file group
- the exact commands they should run, including the commit message you would have used and
  the tag if a release is involved

Write the commands out in full so they can be pasted. Do not attempt a workaround — not
`gh`, not a shell alias, not a script that shells out to git. The block exists so the user
stays the one who decides what enters history; routing around it defeats the point rather
than being helpful.

If the user explicitly asks you to run a git write command anyway, tell them the hook will
deny it and that they need to run it themselves or disable the plugin's hook.
