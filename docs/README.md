# Documentation

Reference for the marketplace and the three plugins it ships. The top-level
[`README.md`](../README.md) is the front door — install commands and a catalog. These pages go
underneath it.

## What are you looking for?

| Question | Read |
|---|---|
| What does this plugin do, and what is in it? | [`plugins/`](plugins/) — one page each |
| How does a repo become a plugin in another project? | [architecture.md](architecture.md) |
| Why isn't my edit taking effect? | [architecture.md](architecture.md#installation-pinning-and-updates) |
| How do I add or change a skill / command / agent? | [authoring.md](authoring.md) |
| What does an exit code mean? Why did nothing happen? | [hooks.md](hooks.md) |
| How do I check my work, and what does CI cover? | [testing-and-ci.md](testing-and-ci.md) |

## The plugins

| Plugin | Scope | Install where |
|---|---|---|
| [`general-code-style`](plugins/general-code-style.md) | File and function size, parameter counts, naming | Everywhere |
| [`android-compose`](plugins/android-compose.md) | Composables, previews, routes, strings, use cases | Android projects |
| [`dev-workflow`](plugins/dev-workflow.md) | Changelog, docs upkeep, git write policy | Everywhere |

## The short version

The marketplace is a plain git repository. `.claude-plugin/marketplace.json` lists three plugins;
each has a manifest and some combination of skills, commands, agents, and hooks, discovered by
directory convention. A project opts in through its `.claude/settings.json` and resolves the
marketplace from GitHub.

Only hooks execute on their own — everything else is markdown that shapes what Claude does when
it is relevant. Installs are pinned to a commit and a version, so **bumping `version` in
`plugin.json` is what makes a change reach clients that already installed the plugin.**

## Keeping these current

The `updating-docs` skill applies to this repo too: after changing a component, update its page
under [`plugins/`](plugins/) and grep these files for claims the change made stale. Numbers go
stale silently — the caps in [hooks.md](hooks.md) and the step list in
[testing-and-ci.md](testing-and-ci.md) are copied from source and have to be re-checked when the
source moves.
