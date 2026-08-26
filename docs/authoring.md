# Authoring components

How to add or change a skill, command, agent, or hook, and the frontmatter each one accepts.

## Which component do I want?

| Want | Use | Loaded |
|---|---|---|
| A rule that applies whenever relevant work happens | **Skill** | Automatically, by description match |
| Something you run deliberately, with arguments | **Command** | On `/name` |
| A focused review or search in its own context | **Agent** | When delegated to |
| Something enforced whether or not anyone asks | **Hook** | At a fixed point in the loop |

Skills are the default. Reach for a hook only when the rule must hold even when nobody is
thinking about it — see [hooks.md](hooks.md).

## Frontmatter

Every component is markdown with a YAML frontmatter block. The keys the client recognises
include:

`name`, `description`, `model`, `allowed-tools`, `disallowed-tools`, `argument-hint`,
`arguments`, `disable-model-invocation`, `user-invocable`, `paths`, `version`, `context`,
`agent`, `hooks`, `mcpServers`, `lspServers`.

Only a few matter in practice, and they differ by component type.

### Skills — `skills/<dir-name>/SKILL.md`

```yaml
---
name: identifying-use-cases
description: Decides whether logic belongs in a UseCase rather than a ViewModel or Repository — coordinating multiple repositories, enforcing a domain rule, cascading writes. Use when adding business logic to a ViewModel or Repository, or creating a new UseCase.
paths: "**/*.kt"
---
```

- `name` **must equal the directory name.** CI enforces this; a rename that updates only one of
  the two makes the skill silently vanish.
- `description` is the whole activation mechanism. At startup only `name` and `description` are
  pre-loaded; the body is read *after* the skill has already been selected, so anything the
  description omits cannot influence whether the skill fires. Write it as **what the skill does
  and when to use it**, in **third person**, with the concrete terms a matching task would
  contain — `@Composable`, `strings.xml`, `CHANGELOG.unreleased.md`. Max 1,024 characters.
  "Follow the guidelines described here" is the anti-pattern: it is pure filler, and it is what
  every skill in this repo said before the descriptions were rewritten.
- **Quote the description only when YAML needs it** — when it contains `: `, contains ` #`, or
  *starts with* one of `@ \` & * ! | > % - ? { } [ ] , " '`. Those characters are harmless
  mid-string, so `@Composable` inside a sentence needs no quotes. The same rule applies to
  `argument-hint`, and there it usually does bite: `[path] [--sweep]` unquoted is two flow
  sequences on one line, which silently invalidates the whole frontmatter block.
- `name` must be lowercase letters, digits, and hyphens, at most 64 characters. Prefer gerund
  form (`creating-composables`, `identifying-use-cases`) over vague or overlong alternatives.
- `paths` is optional gating, see below.

### <a id="paths-gating"></a>`paths` gating

`paths` restricts a skill to files matching a glob, comma-separated for several:

```yaml
paths: "**/*.kt,**/*.xml"
```

This is what keeps the `android-compose` skills quiet in a repo with no Kotlin. Gate every
platform-specific skill. A skill with no `paths` is always eligible, which is correct for the
language-agnostic ones in `general-code-style` and the process ones in `dev-workflow`.

### Commands — `commands/<name>.md`

```yaml
---
name: ship
description: Prepares a release — distills the unreleased scratchpad into one new customer-facing changelog section and sets the project's version constant. Use when cutting a release or bumping a version.
argument-hint: "<version>"
---
```

The filename determines the slash command. `argument-hint` is what the user sees while typing.
In the body, `$1`, `$2` … are positional arguments and `$ARGUMENTS` is everything passed.

Always handle the empty case explicitly. Every command here either asks (`/ship` with no version)
or falls back to the working tree (`/style-check`, `/changelog`, `/extract-strings`) rather than
guessing.

### Agents — `agents/<name>.md`

```yaml
---
name: style-reviewer
description: Reviews code against file-size, function-size, parameter-count, and naming conventions. Use when asked to check style compliance, or after a batch of new files or functions has been written. Read-only — reports findings, never edits.
tools: Read, Grep, Glob, Bash
model: inherit
---
```

`tools` restricts what the agent may do — both agents here are read-only by construction, which
is what makes "it reports, it never edits" a guarantee rather than an instruction. `model:
inherit` uses the parent session's model.

State the read-only contract in the body too. The frontmatter enforces it; the prose is what
stops the agent trying and failing.

## House rules

**Keep language-agnostic rules in `general-code-style`.** Do not restate them in a platform
plugin. Where a platform genuinely needs an exception, state the exception and point at the base
rule — as the composables skill does with the UI-component exemption.

**Write skills as instructions, not essays.** Numbered rules, bold lead-ins, concrete examples.
Every skill in this repo fits on one screen except `identifying-use-cases`, which earns its
length with worked code.

**Every `description` states what it does *and* when to use it.** Both halves, always, for
skills, commands, and agents alike — this follows [Anthropic's skill authoring best
practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
The *what* carries the terms a task will actually contain; the *when* tells the model the
moment has arrived. Drop either half and discovery degrades:

- **What only** — "Explains why git write commands are blocked" — never loads at the moment
  Claude is about to commit, which is the only moment it matters.
- **When only** — "When creating files or classes, follow the instructions explained here" —
  matches nothing specific, because the 200-line cap and the naming rule never reach the matcher.
- **Both** — "Caps source files at ~200 lines … Use when creating a new file or class, splitting
  a file that has grown too large, or naming either."

**Grammar does not control model invocation.** A *what*-only description is not a way to keep a
command user-triggered; it only makes the command harder to find. The field that actually gates
it is `disable-model-invocation: true`, which nothing in this repo sets — so every command here
is reachable both by `/name` and by description matching, and its description is a user-facing
surface either way.

**Know what runs in whose context.** Skills and commands both expand into the *current*
conversation — they see everything already in the session. Only an agent gets a fresh context.
A skill shapes work already underway and is usually meaningless invoked alone; a command brings
its own occasion, which is why only commands take arguments (`$1`, `$ARGUMENTS`) and why every
command here handles the empty case by asking or falling back to the working tree.

**Never assert the consuming project's structure.** Say "find an existing `*UseCase.kt` and match
its package" rather than "use cases live in `domain/usecase/`". The CI leakage step greps for the
phrases that mark this mistake. Examples are fine — assertions are not.

**Cross-reference by bare name** (`` `identifying-use-cases` ``, `` `no-git-writes` ``). Within a
plugin this always resolves; across plugins it resolves when both are installed, so word it as a
pointer rather than a dependency.

## Adding a platform plugin

Platform plugins are named `<platform>-<stack>` — `android-compose` today, with `web-react`,
`backend-supabase`, and `ios-swiftui` reserved.

1. `mkdir -p plugins/<name>/{.claude-plugin,skills,agents,commands,hooks}`
2. Write `.claude-plugin/plugin.json` with at minimum a `name`.
3. Add an entry to `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`, and the
   same `name`.
4. Gate platform-specific skills with `paths`.
5. `claude plugin validate plugins/<name> --strict`

## Changing an existing component

Bump `version` in that plugin's `plugin.json`. The install cache is keyed by version, so without
a bump an installed client has no signal to refetch — see
[architecture.md](architecture.md#installation-pinning-and-updates).

Then run the checks in [testing-and-ci.md](testing-and-ci.md), and update the plugin's page under
[`plugins/`](plugins/) if you changed what a component does.
