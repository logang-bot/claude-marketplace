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
| Command | `/style-check [path] [--sweep]` | Run explicitly |
| Hook | `PostToolUse` on `Write\|Edit` | Automatically, after every file write |
| Script | `scripts/sweep.py` | Via `/style-check` on a large target, or run directly |
| Package | `hooks/style_rules/` | Imported by the hook, the sweep, and the tests |
| Tests | `tests/test_style_rules.py` | In CI, and before pushing a measurement change |

## The rules

| Rule | Target | Hard cap |
|---|---|---|
| File length | ~200 lines | 250 (`FILE_LIMIT`) |
| Function body | ~7 lines | 10 (`FUNCTION_LIMIT`) |
| Parameters | 3 | 3 (`PARAM_LIMIT`) — grouped into a type beyond that |

File length applies to source files — the extensions in `SOURCE_EXTS`, which is also exactly
what the sweep opens. Prose (`.md`, `.rst`, `.txt`, …) and data or markup (`.json`, `.yaml`,
`.xml`, `.lock`, …) are outside it: a long document is a document, a long resource table is
additive, and neither becomes harder to read at line 251.

Import and `package` lines do not count toward file length. Blank lines and comments do not
count toward function body length. Names must be self-describing: if a comment is needed to
explain what a thing does, the name is wrong.

Beyond three parameters, group the related extras into a data class — or the equivalent record,
struct, or interface in the language at hand. Group only fields genuinely related to each other;
a bag named `Params` that holds unrelated values is not an improvement.

## Comments and documentation

The name carries the meaning. A method small enough to satisfy the body-length rule should be
readable without prose, so **explanatory comments inside a body are a defect, not a courtesy** —
they signal that a name is wrong or that the method is doing too much. The fix is a rename or an
extraction, never a comment.

Four kinds of text are not explanation, and stay allowed:

- tool directives — `// noinspection`, `// eslint-disable-next-line`, `#pragma`
- `TODO` and `FIXME` markers, which track future work rather than describe current code
- file header and licence banners
- doc comments on genuinely non-obvious math or algorithms

The first three are recognised mechanically, so the hook and the sweep enforce this rule
inside function bodies. Anything outside a body — a licence banner, a file header, a doc comment
above a declaration — is never examined, and a run of consecutive comment lines is reported once
rather than line by line.

That last one is the only sanctioned way to document behaviour, and it goes **above the
declaration in the platform's own form** — `/// <summary>` in C#, KDoc in Kotlin, JSDoc in
TS/JS, a docstring in Python — never inline, and never on a member whose name already says it.
A formula, a numeric method, or an algorithm whose correctness is not evident from reading the
code qualifies. A getter does not.

## The UI component exemption

Functions that declare UI in a component-based framework — Jetpack Compose composables, React
components, SwiftUI views — are **exempt from the body-length and parameter-count rules**, and
from those two only. They routinely take many optional configuration parameters and read
top-down as markup rather than as procedural logic. The comment rules apply to them exactly as
they apply anywhere else.

The exemption is honoured in three places, and they must agree:

- `creating-methods-or-functions/SKILL.md` states it
- `style-reviewer` is told to note such functions as exempt rather than report them
- `check-size.py` detects them by scanning the four lines above a declaration for `UI_MARKERS`
  (`@Composable`, `@Preview`, `React.FC`, `: FC<`, `some View`)

File length is **not** exempt for UI code. A 400-line screen file is still a finding.

## The size hook

`hooks/check-size.py` runs after every `Write` or `Edit` and measures the file that was just
written. It exits `2` with an advisory on stderr when a rule is broken — the write has already
succeeded, so the message is advice, not a rejection. It checks four things: file length,
function body length, parameter count, and comments that explain code inside a function body.

The script is a thin entry point; the measurements live in `hooks/style_rules/`, a package the
sweep and the tests import too, so no two of them can disagree about a cap.

Body length counts code lines only — `measure_body` drops blank lines, any line opening with
`//`, `#`, `*`, or `/*`, and a docstring opening a Python body. This matches the way file length
already ignores imports, and keeps documentation from eating into a 10-line budget.

Parameter count is measured by `parameter_text`, which joins the declaration's parenthesised
list across up to `DECL_SPAN` (12) lines so a wrapped signature is still read whole, and
`count_parameters`, which splits on top-level commas only — commas nested in generics, default
values, or collection literals do not inflate the count. Lambda arrows and comparisons (`->`,
`=>`, `>=`, `<=`) are stripped first so their angle bracket is not mistaken for generic nesting.

**Every** offender is reported, not just the worst one — a file with six oversized functions
lists six. The advisory stops at `MAX_WARNINGS` (5) and collapses the rest into a count, so it
stays readable without turning into whack-a-mole.

Three tiers, all defined in `hooks/style_rules/limits.py`:

| Tier | Contents | Rules applied |
|---|---|---|
| `MEASURED_LANGS` | `BRACE_LANGS` (Kotlin/`.kts`, Java, JS/TS, Swift, C/C++, C#, Go, Rust, Scala, PHP, Dart, Gradle, Groovy) plus Python | All of them |
| `FILE_ONLY_LANGS` | Ruby, shell, SQL, Obj-C, `.vue`, `.svelte`, Lua, Perl, R, Julia, Elixir, Erlang, Haskell, Clojure, Terraform, and friends | File length only |
| `SOURCE_EXTS` | The union of the two | The scope of both the hook and the sweep |

`FILE_ONLY_LANGS` exists because no body strategy fits those languages: Ruby needs `def`/`end`
matching, `.vue` and `.svelte` mix markup with script, and the rest are simply languages the
declaration patterns were never written for. Adding one there is a one-line change and costs
nothing; adding one to `MEASURED_LANGS` means its declarations must match `DECL` or
`DECL_TYPED` first.

Two ways of finding a body, picked by extension:

- **Braces** — matched from the `{` that follows the closing `)` of the parameter list, not from
  the declaration line. Starting at the declaration is what used to make a wrapped multi-line
  signature — the ordinary Kotlin and TypeScript style — measure a 0-line body and escape the
  rule entirely. Braces inside string literals are ignored.
- **Indentation** — for Python, the body ends at the first non-blank line indented no further
  than the `def`. `self` and `cls` do not count as parameters.

Two declaration patterns are recognised:

- `DECL` — an optional run of modifiers followed by `fun` / `func` / `fn` / `def` / `function`.
  Requiring a real declaration keyword is what stops trailing-lambda calls like `Column(...) {`
  or `items(...) {` being counted as functions.
- `DECL_TYPED` — Java/C#/C++ shape, where modifiers are followed by a return type and then the
  name. There is no keyword to key on, so an access modifier or `static` is required to keep
  the match honest. Only tried for languages not in `KEYWORD_LANGS`.

Nested declarations are skipped by jumping past each function once measured, so a helper
declared inside another function is not double-counted.

See [../hooks.md](../hooks.md) for the exit-code contract and how to test this hook.

## The reviewer

`style-reviewer` is read-only — it reports and never edits. Given a path it reviews that; given
nothing it reviews the uncommitted working tree (`git diff --name-only HEAD` plus
`git ls-files --others --exclude-standard`).

It reports the measurement rather than an impression — "148-line body", not "quite long" — and
is told to be firm on rules 1–3 because they are mechanical, but to raise the naming and comment
rules only when it can name what a reader would actually misunderstand, or the rename that would
remove the need for the comment. It is explicitly instructed not to manufacture findings to fill
a report.

## Two modes, one command

`/style-check` picks its strategy from the size of the target and always says which it chose.

| Target | Mode | Rules covered |
|---|---|---|
| No path — the uncommitted working tree | Agent review | All five |
| A path of 30 files or fewer | Agent review | All five |
| A path over 30 files | Sweep | 1–3, plus in-body comments |
| `--sweep <path>` | Sweep, at any size | 1–3, plus in-body comments |

The threshold exists because the agent *reads* code, and reading is what costs. Past roughly
thirty files it exhausts its context before finishing, so the command measures instead.

Sweep mode states explicitly what it did not evaluate: **naming**, and whether a doc comment
says something its member's name already says. Those two need a judgement about what a reader
would misunderstand, which is not a thing a script can measure. The rest of rule 5 — a comment
that narrates code inside a body — is mechanical, and is measured.

Neither mode applies fixes. A sweep is a worklist, not a task queue — if you ask for fixes
afterwards, they happen one file at a time.

## Adopting this on an existing codebase

Turning a 7-line cap on a mature project produces thousands of findings at once, almost none of
which are worth acting on in isolation. The intended order is:

1. **Let the hook do the work.** It only fires on files you actually write or edit, so the
   codebase converts as you touch it. For code you never open, the rules cost nothing.
2. **Sweep for triage** when you want to know where the damage is: `/style-check --sweep src`.
   It is free, so run it as often as you like.
3. **Review a hotspot** with `/style-check src/the-worst-file` to get rule 4, the judgement
   half of rule 5, and a concrete refactor, on one file at a time.

## The sweep script

`scripts/sweep.py` measures a whole tree. It imports the limits, `measure_file`,
`sized_functions`, and `comment_findings` from `hooks/style_rules/` rather than restating any of
them, so a sweep and a post-write advisory can never disagree about a cap. It puts the plugin's
`hooks/` directory on `sys.path` and imports the package by name.

```
python3 scripts/sweep.py <path> [--top N] [--strict]
```

`--top` caps the file listing (default 20) so a legacy repo does not dump thousands of lines.
`--strict` exits `1` when anything is found, which makes the same script usable as a CI gate;
the default exit is `0` because a report is not a failure.

File discovery uses `SOURCE_EXTS` — the same set the hook measures — with `git ls-files` when
the target is in a repo, so `.gitignore` is respected for free, and a filesystem walk otherwise. Either way `SKIP_DIRS` drops
`node_modules`, `build`, `vendor`, and friends — vendored and generated code is often tracked,
so being in git is not enough to make something worth measuring.

The hook and the sweep now report the same findings; the hook caps its list at five per file
because it interrupts a write, while the sweep lists every one and is ordered by severity. That
shared measurement is what makes the totals trustworthy.
