---
name: git-writes-on-request
description: Allows git write commands (commit, push, tag, merge, rebase, publishing gh commands) only when the user explicitly asks for them, scoped to exactly what was asked, with extra confirmation for anything that rewrites published history. Use when about to commit, push, tag, or open a pull request, when a task is finished and the changes are uncommitted, or when the user asks you to commit or push.
---

**Run git write commands when the user asks for them, and never on your own.** Finishing a
task is not a request to commit it. The developer decides what enters history and when it is
published.

## Allowed on request

`git commit`, `git push`, `git tag`, `git merge`, `git rebase`, `git revert`, `git cherry-pick`,
`git stash pop`, branch creation, and publishing `gh` subcommands (`pr create`, `release create`,
`issue create`, …) all need an explicit request in the current conversation.

Read-only commands need none: `git status`, `git diff`, `git log`, `git show`, `git blame`,
`git ls-files`. Use them freely.

## Scope of a request

- **A request covers only the action it names.** "Commit this" does not mean push. "Push" does
  not mean tag or open a pull request.
- **It covers only the changes it was about.** A commit approved earlier in the session does not
  cover edits made after it. Ask again, or offer.
- **On the default branch, say so** before committing. Offer to branch first if the project
  works with branches.

## Always confirm first

Even when the user has asked in general terms, confirm before running anything that discards
work or rewrites history others may already have:

- `git push --force` / `--force-with-lease`
- `git reset --hard`, `git clean -f`, `git checkout -- <path>` over uncommitted changes
- `git rebase` or `git commit --amend` on commits that are already pushed
- `git branch -D`, `git stash drop` / `clear`
- deleting a remote branch, tag, release, or repository

Name what will be lost or rewritten, then wait for a yes.

## Without a request

Finish the file edits and stop. In one line, offer to commit (and push, if relevant) and give
the commit message you would use. Do not run it.

## Doing it well

- Look first: `git status` and `git diff --staged` before committing, so only the intended files
  go in. Stage files by name rather than `git add -A` when unrelated changes are present.
- Follow the project's commit-message conventions (check `git log`) and any attribution the
  session asks for.
- Never skip hooks (`--no-verify`) or bypass signing unless the user asks for it. If a pre-commit
  hook fails, fix the cause and make a new commit.
- Report what happened: the commit hash, the branch, and whether the push succeeded.
