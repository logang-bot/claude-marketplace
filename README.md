# claude-marketplace

Personal engineering conventions, packaged as installable [Claude Code](https://claude.com/claude-code)
plugins so they travel between projects instead of living in one repo's `.claude/skills/`.

## Install

```
/plugin marketplace add logang-bot/claude-marketplace
/plugin install general-code-style@logang-bot
/plugin install android-compose@logang-bot
/plugin install dev-workflow@logang-bot
/plugin install web-design@logang-bot
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
    "dev-workflow@logang-bot": true,
    "web-design@logang-bot": true
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
| Skill | `creating-files-or-classes` | ~200-line file cap, split when approaching it, self-describing names, properties before constructors before methods |
| Skill | `creating-methods-or-functions` | ~7-line bodies, max 3 parameters, intent-revealing names, no explanatory comments, each helper below its caller |
| Agent | `style-reviewer` | Read-only review against the size, parameter, member-order, naming, and comment rules |
| Agent | `senior-reviewer` | Read-only design review — cohesion, coupling, leaky abstractions, testability |
| Agent | `leak-hunter` | Finds leaked resources across every lifecycle and fixes them, reporting each edit |
| Command | `/style-check [path] [--sweep]` | Reviews a diff or small path with the agent; sweeps a large one mechanically |
| Command | `/design-review [path]` | Runs the design review over a diff or a module |
| Command | `/leak-check [path] [--report-only]` | Hunts and fixes leaks; `--report-only` reviews without editing |
| Script | `scripts/sweep.sh` | Measures a whole tree against the size rules, no model involved |
| Hook | `SubagentStart` | Hands every subagent the rules, since a fresh context matches no skill descriptions |
| Hook | `UserPromptSubmit`, `PreToolUse` | Hands the main thread the caps while it plans, and the rules when the plan is accepted |
| Hook | `PostToolBatch` | Requires a fix when a written file or function exceeds the caps, takes too many parameters, or declares a member out of order |
| Hook | `Stop` | Measures the files git reports the turn worked on, catching writes made by a shell command or another tool |

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
| Skill | `creating-or-updating-screen-routes` | Screens own their ViewModels; nav passes primitives only |
| Skill | `writing-user-facing-strings` | User-facing text goes to `strings.xml` |
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
| Skill | `git-writes-on-request` | Commit, push, and tag only when the user asks; confirm before rewriting history |
| Command | `/changelog <text>` | Appends a bullet to the unreleased scratchpad |
| Command | `/ship <version>` | Distills the scratchpad into a release section and bumps the version |
| Hook | `Stop` | Reminds when code changed but nothing in `docs/` did |

The changelog skill deliberately carries no project specifics. It looks up four things at
release time — the version-constant location, the release-notes language and audience, any
length cap, and pre-release deployment steps — searching the project's `CLAUDE.md`, then a
release document under `docs/`, then the changelog files' own headers. A project using this
plugin should document those four things in one of those places.

### `web-design`

Web front ends. Every design choice follows from a website personality, recorded with its tokens
in the project's `DESIGN.md`. Day to day you run the two commands and make ordinary requests; the
skills load on their own and the hooks apply the rules whether or not a skill was loaded.

| Use case | Commands |
|---|---|
| Start a new web app | `/design-brief` → build page by page → `/design-audit <page>` |
| Revise an existing project | `/design-audit src --lint-only` → `/design-brief` → `/design-audit <page>` per page |
| A style that fits none of the seven personalities | `/design-brief "describe the style"` (or `/design-brief custom` for an existing project) |
| Review one page or section | `/design-audit the pricing page` |
| Check uncommitted work | `/design-audit` |

More use cases, and every component in detail: [`docs/plugins/web-design.md`](docs/plugins/web-design.md).

| Component | Name | What it does |
|---|---|---|
| Command | `/design-brief [personality \| custom \| "description"]` | Decides the design: asks what it cannot infer about purpose, audience and feel, picks one of seven personalities or defines a custom one, and writes `DESIGN.md` with its tokens and any rules the style deliberately relaxes. Does not check code |
| Command | `/design-audit [path or description] [--dirty] [--lint-only]` | Checks code against the rules and `DESIGN.md`: always the linter, plus both reviewer agents on a target of 30 files or fewer. Accepts paths or a page named in plain words; no argument means uncommitted work; `--lint-only` skips the agents |
| Skill | `choosing-a-website-personality` | Seven personalities and what each implies, plus blends and custom personalities when none fits |
| Skill | `writing-a-design-brief` | The `DESIGN.md` format, including the `tokens` block the linter reads |
| Skill | `setting-typography` | One or two proven typefaces, a type scale, 16–32px body text, weight ≥ 400, < 75 characters a line, line-height 1.5–2 |
| Skill | `building-color-palettes` | Main colour plus grey, tints and shades as tokens, no pure black, 4.5:1 contrast |
| Skill | `using-images-and-illustrations` | Relevant, original-looking imagery, three ways to put text over images, 2x and compressed, matching dimensions |
| Skill | `using-icons` | One SVG pack matched to the type, text-coloured, enclosed in a shape rather than scaled up |
| Skill | `applying-shadows-and-radius` | Light shadows in a sm/md/lg scale, radius matched to the typeface and taken from a fixed set |
| Skill | `spacing-with-whitespace` | Section > group > element spacing, proximity, a fixed spacing scale |
| Skill | `establishing-visual-hierarchy` | Position, size, weight, colour and whitespace to rank what matters |
| Skill | `designing-for-user-experience` | Known patterns, descriptive CTAs, links-only underline, 200–500ms animation, single-column forms, plain copy |
| Skill | `composing-components-and-layouts` | A catalogue of components and layout patterns, assembled into a page |
| Agent | `design-reviewer` | Read-only review of personality fit and visual design (areas 01–08): the judgement calls the linter cannot make |
| Agent | `ux-reviewer` | Read-only review of UX, copy and layout (areas 09–10) |
| Script | `scripts/audit.sh` | The linter: 21 measurable rules over CSS, HTML, Tailwind and CSS-in-JS, following DESIGN.md's scales and relaxed rules. `--dirty` for uncommitted files, `--strict` to use it as a pre-commit gate |
| Hook | `SubagentStart` | Gives subagents in a web project the rules, since they never load the skills themselves |
| Hook | `UserPromptSubmit` | Records the uncommitted web files as a baseline. When a prompt is about design, tells Claude to settle the personality first; without `DESIGN.md`, Claude asks you before building new pages whether to create it with `/design-brief` or let it decide the style |
| Hook | `PreToolUse` | Gives Claude the rules just before its first page or stylesheet write of the session; without `DESIGN.md`, the first new page also triggers the create-or-decide question |
| Hook | `PostToolBatch` | Lints the web files a batch of writes produced and asks Claude to fix the findings now |
| Hook | `Stop` | Lints everything the request changed, however it was written, and asks Claude to mention `/design-audit` once |

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

Hook scripts are POSIX shell and awk, so they run wherever git does — including Git Bash on
Windows, which is the shell Claude Code uses for hooks there. They read the hook payload on
stdin; the docs reminder in `dev-workflow` answers with exit 2, while the style hooks answer on
stdout with `hookSpecificOutput.additionalContext`, which reaches the model as feedback rather
than as an error. Every one exits 0 on malformed input, a missing file, or a non-git directory,
so a broken hook degrades to silence rather than blocking work.

## Documentation

Deeper reference lives in [`docs/`](docs/):

| Page | Covers |
|---|---|
| [`docs/plugins/`](docs/plugins/) | One page per plugin — every skill, command, agent, and hook |
| [`docs/architecture.md`](docs/architecture.md) | Discovery chain, consumer settings, install pinning and updates |
| [`docs/authoring.md`](docs/authoring.md) | Frontmatter reference and how to add a component |
| [`docs/hooks.md`](docs/hooks.md) | Every hook, the exit-code contract, how to test one |
| [`docs/testing-and-ci.md`](docs/testing-and-ci.md) | Local checks, what `validate.yml` covers, release steps |

## License

MIT
