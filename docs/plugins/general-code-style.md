# `general-code-style`

Language-agnostic rules for how big things are allowed to get and how clearly they must be
named. Nothing in it is tied to a platform, a framework, or a build system.

**Install it everywhere.** It is the base layer; platform plugins add to it rather than
restating it.

## Components

| Kind | Name | Fires when |
|---|---|---|
| Skill | `creating-files-or-classes` | A file or class is being created |
| Skill | `creating-methods-or-functions` | A method or function is being written |
| Agent | `style-reviewer` | Asked to check style, or after a batch of new code |
| Command | `/style-check [path]` | Run explicitly |
| Hook | `PostToolUse` on `Write\|Edit` | Automatically, after every file write |

## The rules

| Rule | Target | Hard cap |
|---|---|---|
| File length | ~200 lines | 250 (`FILE_LIMIT`) |
| Function body | ~10 lines | 15 (`FUNCTION_LIMIT`) |
| Parameters | 3 | — grouped into a type beyond that |

Import and `package` lines do not count toward file length. Names must be self-describing:
if a comment is needed to explain what a thing does, the name is wrong.

Beyond three parameters, group the related extras into a data class — or the equivalent record,
struct, or interface in the language at hand. Group only fields genuinely related to each other;
a bag named `Params` that holds unrelated values is not an improvement.

Document a signature only when the parameter meaning, or the interaction between calls, would
not be obvious to a reader unfamiliar with the context.

## The UI component exemption

Functions that declare UI in a component-based framework — Jetpack Compose composables, React
components, SwiftUI views — are **exempt from the body-length and parameter-count rules**. They
routinely take many optional configuration parameters and read top-down as markup rather than as
procedural logic.

The exemption is honoured in three places, and they must agree:

- `creating-methods-or-functions/SKILL.md` states it
- `style-reviewer` is told to note such functions as exempt rather than report them
- `check-size.py` detects them by scanning the four lines above a declaration for `UI_MARKERS`
  (`@Composable`, `@Preview`, `React.FC`, `: FC<`, `some View`)

File length is **not** exempt. A 400-line screen file is still a finding.

## The size hook

`hooks/check-size.py` runs after every `Write` or `Edit` and measures the file that was just
written. It exits `2` with an advisory on stderr when a cap is exceeded — the write has already
succeeded, so the message is advice, not a rejection.

Function measurement only applies to brace languages (`BRACE_LANGS`: Kotlin, Java, JS/TS, Swift,
C/C++, C#, Go, Rust, Scala, PHP). Two declaration patterns are recognised:

- `DECL` — an optional run of modifiers followed by `fun` / `func` / `fn` / `def` / `function`.
  Requiring a real declaration keyword is what stops trailing-lambda calls like `Column(...) {`
  or `items(...) {` being counted as functions.
- `DECL_TYPED` — Java/C#/C++ shape, where modifiers are followed by a return type and then the
  name. There is no keyword to key on, so an access modifier or `static` is required to keep
  the match honest. Only tried for languages not in `KEYWORD_LANGS`.

Only the **longest** top-level function is reported. Nested declarations are skipped by jumping
past each function once measured, so a helper declared inside another function is not
double-counted.

See [../hooks.md](../hooks.md) for the exit-code contract and how to test this hook.

## The reviewer

`style-reviewer` is read-only — it reports and never edits. Given a path it reviews that; given
nothing it reviews the uncommitted working tree (`git diff --name-only HEAD` plus
`git ls-files --others --exclude-standard`).

It reports the measurement rather than an impression — "148-line body", not "quite long" — and
is told to be firm on rules 1–3 because they are mechanical, but to raise the naming rule only
when it can name what a reader would actually misunderstand. It is explicitly instructed not to
manufacture findings to fill a report.

`/style-check [path]` is a thin wrapper: it launches the agent, relays findings grouped by file
most-severe-first, and applies nothing unless you ask afterwards.
