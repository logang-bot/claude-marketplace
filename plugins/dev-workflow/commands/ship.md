---
name: ship
description: Prepare a release — distill the unreleased scratchpad into a new changelog section and bump the version
argument-hint: <version>
---

Prepare the release for version `$1`. If `$1` is empty, ask for the version rather than
inferring one.

Follow the `updating-changelog-or-release-notes` skill. In order:

1. **Read the project's `CLAUDE.md`** for where the version constant lives, the language and
   audience of the release notes, any length cap, and any pre-release deployment steps. If it
   does not say, ask — a mismatched version header usually fails the release build.
2. **Read `CHANGELOG.unreleased.md`** in full. It holds everything to announce.
3. **Set the version constant** to `$1` where `CLAUDE.md` says it lives.
4. **Write one new `## [$1]` section** at the top of the version list in `CHANGELOG.md`,
   distilled from the pending bullets: what changes for the person using the software, in
   that file's existing language and house style, within any length cap. Never file or class
   names. A change with no user-visible effect is described plainly as such, not dressed up
   as a feature.
5. **Reset `CHANGELOG.unreleased.md`**, leaving the header and an empty pending section.

Then **stop**. Do not run git — no commit, no tag, no push. Print for the user:

- the version and the exact tag to push
- the commit message you would have used
- any pre-release deployment steps `CLAUDE.md` lists, called out as blocking

Report the character count of the new section if the project has a cap, so the user can see
it fits.
