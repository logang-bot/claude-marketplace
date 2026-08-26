# Architecture

How this repository becomes working plugins in another project, end to end.

## The discovery chain

```
.claude-plugin/marketplace.json     the catalog: name, owner, one entry per plugin
        │  each entry's "source": "./plugins/<name>"
        ▼
plugins/<name>/.claude-plugin/plugin.json    the manifest: name, version, author, repo
        │  siblings, discovered by convention — no file lists them
        ▼
plugins/<name>/
    skills/<skill-name>/SKILL.md    markdown instructions, loaded on relevance
    commands/<name>.md              slash commands, invoked explicitly
    agents/<name>.md                subagent definitions
    hooks/hooks.json                the only components that execute on their own
```

Two names must agree, and CI checks it: the `name` in a marketplace entry and the `name` in that
plugin's `plugin.json`. Component directories are found by convention — adding a skill means
creating a folder, not registering it anywhere.

## The consumer side

A project opts in through its `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "logang-bot": {
      "source": { "source": "github", "repo": "logang-bot/claude-marketplace" }
    }
  },
  "enabledPlugins": {
    "general-code-style@logang-bot": true,
    "android-compose@logang-bot": true,
    "dev-workflow@logang-bot": true
  }
}
```

Two things go wrong here easily:

- **The key under `extraKnownMarketplaces` must equal the `@`-suffix on every plugin id.** Both
  are the marketplace `name` from `marketplace.json`. Keying it `foo` while installing
  `plugin@logang-bot` resolves nothing.
- **`enabledPlugins` values are booleans.** An extended object form exists for version
  constraints, but `true` is the ordinary case.

Settings precedence runs **user < project < local < flag < policy**. To disable a plugin that
project settings enable, set it to `false` in `.claude/settings.local.json` — setting `false` in
`~/.claude/settings.json` is overridden by the project.

## Installation, pinning, and updates

An install is recorded in `~/.claude/plugins/installed_plugins.json`, one entry per consuming
project:

```json
"dev-workflow@logang-bot": [
  {
    "projectPath": "/path/to/some-project",
    "installPath": "~/.claude/plugins/cache/logang-bot/dev-workflow/0.1.0",
    "version": "0.1.0",
    "gitCommitSha": "976fcedb897602887c3f802eaeb3de4d98036d02"
  }
]
```

Three consequences worth internalising:

1. **Installs are pinned to a commit.** Pushing a broken commit does not retroactively break a
   project that already installed an earlier one. It stays on its recorded SHA until something
   updates it.
2. **The cache path is keyed by `version`.** Bumping `version` in `plugin.json` is what signals
   installed clients that there is a new build to fetch. Shipping meaningful changes while
   leaving the version untouched is the most likely reason an edit "didn't take".
3. **A fresh install has no pin to protect it.** A new machine, a new clone, or a teammate
   running `/plugin install` resolves from the default branch *at that moment* and gets whatever
   is there — broken or not, with no action on their part.

The marketplace itself is cloned to `~/.claude/plugins/marketplaces/<name>/` and tracked in
`known_marketplaces.json` alongside a `lastUpdated` timestamp.

### `autoUpdate`

Marketplaces accept a per-marketplace `autoUpdate` option, described in the client as *whether
to automatically update this marketplace and its installed plugins on startup*. It is not set
anywhere in this setup, so the built-in default governs. If you want pinning to be a guarantee
rather than an assumption, set it explicitly:

```json
"logang-bot": {
  "source": { "source": "github", "repo": "logang-bot/claude-marketplace" },
  "autoUpdate": false
}
```

Pinning is a delay, not a safety mechanism — consumers have to update eventually or the
marketplace has no purpose. Keeping the default branch green is the actual protection; see
[testing-and-ci.md](testing-and-ci.md#ci-is-a-report-not-a-gate).

## What executes where

The two halves of this repo never meet, and confusing them causes wasted debugging:

| | Runs where | Runs when | Can see |
|---|---|---|---|
| Skills, commands, agents | Your machine, inside a Claude session | When relevant or invoked | The project you are working in |
| Hooks | Your machine, inside a Claude session | At fixed points in the loop | The tool payload and the working directory |
| `.github/workflows/validate.yml` | GitHub's runners | On push and pull request | Only this repo's committed contents |

No skill can reach the workflow, and the workflow cannot see a Claude session. They check
overlapping rules from opposite ends: hooks advise while code is written, CI re-checks what
actually got committed.

## Developing against a local checkout

Because a consuming project resolves the marketplace from GitHub, edits here are not live until
they are pushed. To test before pushing, point Claude at this checkout:

```
/plugin marketplace add /path/to/claude-marketplace
/reload-plugins
```

`/reload-plugins` picks up further edits without restarting the session. This repo's own
`.claude/settings.json` is gitignored so it can hold whichever of the two you are currently
using.
