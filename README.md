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

The marketplace is named `restrusher` while the repo is hosted under `logang-bot`, so the
`add` line uses the repo path and the `@logang-bot` suffix is the marketplace identity. They
are separate on purpose; both are correct as written.

To enable them automatically for everyone working in a project, commit this to the project's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "restrusher": {
      "source": { "source": "github", "repo": "logang-bot/claude-marketplace" }
    }
  },
  "enabledPlugins": {
    "general-code-style@logang-bot": { "enabled": true },
    "android-compose@logang-bot": { "enabled": true },
    "dev-workflow@logang-bot": { "enabled": true }
  }
}
```

## Plugins

### `general-code-style`

Language-agnostic. Install everywhere.

| Component | Name | What it does |
|---|---|---|
| Skill | `creating-files-or-classes` | ~200-line file cap, split when approaching it, self-describing names |
| Skill | `creating-methods-or-functions` | ~10-line bodies, max 3 parameters, intent-revealing names |
| Agent | `style-reviewer` | Read-only review against the size, parameter, and naming rules |
| Command | `/style-check [path]` | Runs the reviewer over a path or the uncommitted diff |
| Hook | `PostToolUse` | Warns when a written file or function exceeds the caps |

UI component functions (Compose composables, React components, SwiftUI views) are exempt from
the body-length and parameter rules, in both the skill and the hook.

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
| Skill | `updating-changelog-or-release-notes` | Two-file changelog discipline; reads project `CLAUDE.md` for specifics |
| Skill | `updating-docs` | Every behaviour change ends with a docs update and a stale-claim sweep |
| Skill | `no-git-writes` | Why git writes are blocked and what to do instead |
| Command | `/changelog <text>` | Appends a bullet to the unreleased scratchpad |
| Command | `/ship <version>` | Distills the scratchpad into a release section and bumps the version |
| Hook | `PreToolUse` | Denies `git commit`/`push`/`tag`/`rebase` and publishing `gh` subcommands |
| Hook | `Stop` | Reminds when code changed but nothing in `docs/` did |

The changelog skill deliberately carries no project specifics. It reads the project's
`CLAUDE.md` for the version-constant location, the release-notes language, any length cap, and
pre-release deployment steps. A project using this plugin should document those four things.

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

# Install from a local checkout, without pushing
/plugin marketplace add /path/to/claude-marketplace

# Reload after editing, without restarting the session
/reload-plugins
```

Hook scripts are Python 3 with no third-party dependencies. They read the hook payload on
stdin and exit 2 to surface a message; every one exits 0 on malformed input, a missing file,
or a non-git directory, so a broken hook degrades to silence rather than blocking work.

## License

MIT
