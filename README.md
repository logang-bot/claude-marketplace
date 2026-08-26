# claude-marketplace

Personal engineering conventions, packaged as installable [Claude Code](https://claude.com/claude-code)
plugins so they travel between projects instead of living in one repo's `.claude/skills/`.

## Install

```
/plugin marketplace add logang-bot/claude-marketplace
/plugin install general-code-style@logang-bot
/plugin install android-compose@logang-bot
/plugin install dev-workflow@logang-bot
```

To enable them automatically for everyone working in a project, commit this to the project's
`.claude/settings.json`:

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

The key under `extraKnownMarketplaces` and the `@`-suffix on each plugin id are the same thing —
the marketplace name from `.claude-plugin/marketplace.json`. They must match.

## Plugins

### `general-code-style`

Language-agnostic. Install everywhere.

| Component | Name | What it does |
|---|---|---|
| Skill | `creating-files-or-classes` | ~200-line file cap, split when approaching it, self-describing names |
| Skill | `creating-methods-or-functions` | ~7-line bodies, max 3 parameters, intent-revealing names, no explanatory comments |
| Agent | `style-reviewer` | Read-only review against the size, parameter, naming, and comment rules |
| Command | `/style-check [path] [--sweep]` | Reviews a diff or small path with the agent; sweeps a large one mechanically |
| Script | `scripts/sweep.py` | Measures a whole tree against the size rules, no model involved |
| Hook | `PostToolUse` | Warns when a written file or function exceeds the caps, or takes too many parameters |

UI component functions (Compose composables, React components, SwiftUI views) are exempt from
the body-length and parameter rules — and from those two only — in both the skill and the hook.
The comment rules apply everywhere.

### `android-compose`

Android, Kotlin, and Jetpack Compose. Skills are gated with `paths` so they activate only when
Kotlin or Android resource files are in play.

| Component | Name | What it does |
|---|---|---|
| Skill | `creating-composables` | `Modifier` first optional param, split into children, no business logic |
| Skill | `creating-preview-of-composable` | Previews in the same file, light + dark variants |
| Skill | `creating-or-update-new-screen-routes` | Screens own their ViewModels; nav passes primitives only |
| Skill | `writing-a-string-variable-or-text-in-a-code-file` | User-facing text goes to `strings.xml` |
| Skill | `identifying-use-cases` | When logic belongs in a UseCase rather than a ViewModel |
| Agent | `android-architecture-reviewer` | Read-only layering review |
| Command | `/new-screen <Name>` | Scaffolds screen, ViewModel, route, and previews |
| Command | `/extract-strings [path]` | Moves hardcoded UI strings into `strings.xml` |

### `dev-workflow`

Process rules. Platform-agnostic.

| Component | Name | What it does |
|---|---|---|
| Skill | `updating-changelog-or-release-notes` | Two-file changelog discipline; looks up the project's own release specifics |
| Skill | `updating-docs` | Every behaviour change ends with a docs update and a stale-claim sweep |
| Skill | `no-git-writes` | Why git writes are blocked and what to do instead |
| Command | `/changelog <text>` | Appends a bullet to the unreleased scratchpad |
| Command | `/ship <version>` | Distills the scratchpad into a release section and bumps the version |
| Hook | `PreToolUse` | Denies `git commit`/`push`/`tag`/`rebase` and publishing `gh` subcommands |
| Hook | `Stop` | Reminds when code changed but nothing in `docs/` did |

The changelog skill deliberately carries no project specifics. It looks up four things at
release time — the version-constant location, the release-notes language and audience, any
length cap, and pre-release deployment steps — searching the project's `CLAUDE.md`, then a
release document under `docs/`, then the changelog files' own headers. A project using this
plugin should document those four things in one of those places.

## Adding a platform plugin

Platform plugins are named `<platform>-<stack>`: `android-compose` today, with
`web-react`, `backend-supabase`, and `ios-swiftui` as the reserved names. To add one:

1. `mkdir -p plugins/<name>/{.claude-plugin,skills,agents,commands,hooks}`
2. Write `.claude-plugin/plugin.json` with at minimum a `name`.
3. Add an entry to `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
4. Gate platform-specific skills with `paths` so they stay quiet elsewhere.
5. `claude plugin validate plugins/<name> --strict`

Keep genuinely language-agnostic rules in `general-code-style` rather than duplicating them
per platform.

## Development

```bash
# Validate every plugin
for p in plugins/*/; do claude plugin validate "$p" --strict; done
```

Edits here are not live until they are pushed, because a project's `.claude/settings.json`
resolves the marketplace from GitHub. To test a change before pushing it, point Claude at this
checkout instead:

```
/plugin marketplace add /path/to/claude-marketplace
/reload-plugins
```

`/reload-plugins` picks up further edits without restarting the session. This repo's own
`.claude/settings.json` is gitignored so it can hold whichever of the two you are using.

Hook scripts are Python 3 with no third-party dependencies. They read the hook payload on
stdin and exit 2 to surface a message; every one exits 0 on malformed input, a missing file,
or a non-git directory, so a broken hook degrades to silence rather than blocking work.

## Documentation

Deeper reference lives in [`docs/`](docs/):

| Page | Covers |
|---|---|
| [`docs/plugins/`](docs/plugins/) | One page per plugin — every skill, command, agent, and hook |
| [`docs/architecture.md`](docs/architecture.md) | Discovery chain, consumer settings, install pinning and updates |
| [`docs/authoring.md`](docs/authoring.md) | Frontmatter reference and how to add a component |
| [`docs/hooks.md`](docs/hooks.md) | The three hooks, the exit-code contract, how to test one |
| [`docs/testing-and-ci.md`](docs/testing-and-ci.md) | Local checks, what `validate.yml` covers, release steps |

## License

MIT
