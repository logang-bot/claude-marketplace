# `dev-workflow`

Process rules rather than code rules: how changes get recorded, how releases are prepared, how
documentation stays true, and who is allowed to write to git.

**Platform-agnostic.** Nothing here assumes a language or a build system.

## Components

| Kind | Name | Fires when |
|---|---|---|
| Skill | `updating-changelog-or-release-notes` | Recording a change, bumping a version, preparing a release |
| Skill | `updating-docs` | A behaviour change is complete and the project has `docs/` |
| Skill | `no-git-writes` | A git write is attempted or discussed |
| Command | `/changelog <text>` | Run explicitly |
| Command | `/ship <version>` | Run explicitly |
| Hook | `PreToolUse` on `Bash` | Automatically, before every shell command |
| Hook | `Stop` | Automatically, at the end of every turn |

## The two-file changelog

The plugin assumes two files with different audiences, and creates them in this shape if the
project has only one, or none:

| File | Audience | Written |
|---|---|---|
| `CHANGELOG.unreleased.md` | Developers | Continuously, as changes land |
| `CHANGELOG.md` | Customers | Only at release time, one `## [VERSION]` section per version |

If a project uses different filenames, the skill finds them rather than assuming — but keeps the
same split of roles.

Changes with no user or security impact are skipped entirely: internal refactors, docs, tests,
tooling.

## The three-place lookup

The skill carries **no project specifics**. At release time it looks up four things, searching
in this order:

1. the project's `CLAUDE.md`
2. a release or shipping document under `docs/`
3. the headers of the changelog files themselves

What it needs:

| Value | Why it matters |
|---|---|
| Where the version constant lives | The release pipeline usually requires the changelog header to match it exactly |
| Language and audience of `CHANGELOG.md` | Not always English, not always written for developers |
| Any length limit | Some pipelines forward release notes to a channel with a hard cap |
| Pre-release deployment steps | Migrations or services that must be deployed first |

If none of the three say, it asks rather than guessing — getting the version header wrong
typically fails the release build.

> A project consuming this plugin should document those four things in one of those places.

## `/changelog` and `/ship`

`/changelog <text>` appends one short bullet to the pending section of the unreleased scratchpad.
Developer-facing English is fine there. Given no argument it inspects the working tree and
proposes a bullet for you to confirm. It never touches `CHANGELOG.md`.

`/ship <version>` prepares a release: reads the project's release docs, reads the scratchpad in
full, sets the version constant, distills all pending bullets into **one** new `## [VERSION]`
section in the house style, and resets the scratchpad to an empty pending section. A change with
no user-visible effect is described plainly as such rather than dressed up as a feature.

Then it **stops** and prints the version, the exact tag to push, the commit message it would have
used, and any pre-release deployment steps called out as blocking. It does not run git — see
below.

## Documentation upkeep

`updating-docs` holds that a change is finished when the documentation matches the code again,
and that the step people skip is the one that matters:

1. Update the doc covering what you changed.
2. **Sweep sibling docs for claims your change made stale** — grep `docs/` for the names of
   things you touched: the class, the table, the flag, the endpoint, the setting.
3. Check the numbers — schema versions, dependency versions, counts, limits, defaults quoted in
   prose go stale silently.

The reasoning: a doc that is confidently wrong costs more than a doc that is missing.

Internal refactors that change no behaviour, no interface, and no operational procedure need no
doc update. The scope rule is to update what you changed and mention unrelated imperfect docs to
the user rather than rewriting them.

## The git-write policy

**The developer runs all git write commands themselves.** This is deliberate policy, enforced by
a `PreToolUse` hook rather than by good intentions.

Blocked: `commit`, `push`, `tag` (unless listing), `merge`, `rebase`, `revert`, `cherry-pick`,
`reset --hard`, `checkout -b/-B`, `switch -c/-C`, `branch -d/-D`, `stash drop/clear/pop`,
`clean -f`, `filter-branch`, and the publishing `gh` subcommands (`pr create|merge|close|…`,
`release create|…`, `repo create|…`, `issue create|…`).

Not blocked: everything read-only — `status`, `diff`, `log`, `show`, `blame`, `ls-files` — plus
plain `git reset` (unstaging) and plain `git stash`.

When blocked, the expected behaviour is to finish the file edits, then stop and hand over: what
changed, and the exact commands to paste including the commit message. Routing around the block
with `gh`, an alias, or a script defeats its point, which is that you stay the one deciding what
enters history.

See [../hooks.md](../hooks.md#block-git-writespy) for how the matching actually works and how to
test it.
