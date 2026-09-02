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
| Agent | `senior-reviewer` | Asked for a design or architecture review, or before a refactor |
| Agent | `leak-hunter` | Asked about leaks, or after code that acquires a resource |
| Command | `/style-check [path] [--sweep]` | Run explicitly |
| Command | `/design-review [path]` | Run explicitly |
| Command | `/leak-check [path] [--report-only]` | Run explicitly |
| Hook | `PostToolUse` on `Write\|Edit\|MultiEdit\|NotebookEdit` | After every write that names a file |
| Hook | `Stop` | At end of turn, over files git reports as new — whatever tool created them |
| Script | `scripts/sweep.sh` | Via `/style-check` on a large target, or run directly |
| Modules | `hooks/lib/*.awk` | Loaded by the hooks, the sweep, and the tests |
| Tests | `tests/test_*.sh` | In CI, and before pushing a measurement change |

## The size and naming rules

| Rule | Target | Hard cap |
|---|---|---|
| File length | ~200 lines | 250 (`FILE_LIMIT`) |
| Function body | ~7 lines | 10 (`FUNCTION_LIMIT`) |
| Parameters | 3 | 3 (`PARAM_LIMIT`) — grouped into a type beyond that |

File length applies to source files — the extensions in `SOURCE`, which is also exactly
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
- `blocks.awk` detects them by scanning the four lines above a declaration for the UI markers
  (`@Composable`, `@Preview`, `React.FC`, `: FC<`, `some View`)

File length is **not** exempt for UI code. A 400-line screen file is still a finding.

## The size hook

`hooks/check-size.sh` runs after every write that names a file and measures the file that was just
written. It exits `2` with an advisory on stderr when a rule is broken — the write has already
succeeded, so the message is advice, not a rejection. It checks four things: file length,
function body length, parameter count, and comments that explain code inside a function body.

The script is a thin entry point; the measurements live in `hooks/lib/`, a set of awk modules the
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

Three tiers, all defined in `hooks/lib/limits.awk`:

| Tier | Contents | Rules applied |
|---|---|---|
| `MEASURED` | `BRACE` (Kotlin/`.kts`, Java, JS/TS, Swift, C/C++, C#, Go, Rust, Scala, PHP, Dart, Gradle, Groovy) plus Python | All of them |
| `FILE_ONLY` | Ruby, shell, awk, SQL, Obj-C, `.vue`, `.svelte`, Lua, Perl, R, Julia, Elixir, Erlang, Haskell, Clojure, Terraform, and friends | File length only |
| `SOURCE` | The union of the two | The scope of both the hook and the sweep |

`FILE_ONLY` exists because no body strategy fits those languages: Ruby needs `def`/`end`
matching, `.vue` and `.svelte` mix markup with script, and the rest are simply languages the
declaration patterns were never written for. Adding one there is a one-line change and costs
nothing; adding one to `MEASURED` means its declarations must match `decl_name()` or
`typed_name()` first.

Two ways of finding a body, picked by extension:

- **Braces** — matched from the `{` that follows the closing `)` of the parameter list, not from
  the declaration line. Starting at the declaration is what used to make a wrapped multi-line
  signature — the ordinary Kotlin and TypeScript style — measure a 0-line body and escape the
  rule entirely. Braces inside string literals are ignored.
- **Indentation** — for Python, the body ends at the first non-blank line indented no further
  than the `def`. `self` and `cls` do not count as parameters.

Two declaration patterns are recognised:

- `decl_name()` — an optional run of modifiers followed by `fun` / `func` / `fn` / `def` /
  `function`. Requiring a real declaration keyword is what stops trailing-lambda calls like
  `Column(...) {` or `items(...) {` being counted as functions.
- `typed_name()` — Java/C#/C++ shape, where modifiers are followed by a return type and then
  the name. There is no keyword to key on, so an access modifier or `static` is required to
  keep the match honest. Only tried for languages not in `KEYWORD`.

  The Python original captured the name with a lazy quantifier, which ERE has no equivalent
  for. `typed_name()` validates the shape with a greedy pattern and then takes the identifier
  immediately before the parameter list, which is the same name in every real declaration.

Nested declarations are skipped by jumping past each function once measured, so a helper
declared inside another function is not double-counted.

See [../hooks.md](../hooks.md) for the exit-code contract and how to test this hook.

## The three agents

The three divide the same code between them and are written not to overlap. `style-reviewer`
measures how code is written, `senior-reviewer` judges how it is structured, and `leak-hunter`
follows what it acquires. Each is told explicitly to leave the others' territory alone, because
three agents reporting the same file is how a report stops being read.

Two are read-only. `leak-hunter` is the one exception in this marketplace, and the reasons it is
safe to let it edit are set out below.

### `style-reviewer`

`style-reviewer` is read-only — it reports and never edits. Given a path it reviews that; given
nothing it reviews the uncommitted working tree (`git diff --name-only HEAD` plus
`git ls-files --others --exclude-standard`).

It reports the measurement rather than an impression — "148-line body", not "quite long" — and
is told to be firm on rules 1–3 because they are mechanical, but to raise the naming and comment
rules only when it can name what a reader would actually misunderstand, or the rename that would
remove the need for the comment. It is explicitly instructed not to manufacture findings to fill
a report.

### `senior-reviewer`

Read-only, and the only agent here whose findings are judgement rather than measurement. It
reviews design: cohesion, coupling and dependency direction, whether an abstraction leaks its
implementation, whether the code has a seam it can be tested through, where state and side
effects live, duplication against premature abstraction, and whether failures are modelled or
swallowed.

Being open-ended is what makes it useful and also what would make it noisy, so one rule holds
it in place: **every finding must name a concrete consequence** — the change that becomes
expensive, or the bug the structure invites. "Every new payment type needs an edit in three
files" is a consequence; "this violates single responsibility" is a label, and a finding that
can only produce the label is a preference and gets dropped. Findings are ordered by blast
radius and split into **structural** and **judgement**, so a defensible alternative is never
presented as a defect.

It is told to read the callers before judging — a class that looks like a grab-bag may be the
only sensible seam in its context — and to stay out of `style-reviewer`'s territory entirely.
Correctly applied patterns, idiom, one-off scripts, and test code judged as production code are
all explicitly not findings.

### `leak-hunter`

The one agent in this marketplace that edits. It finds resources acquired and never released,
applies the fix, and reports every change it made.

It is framed around **resource lifecycles** rather than memory, which is what lets one rule set
work in a garbage-collected language and a manually managed one at once. In the first, a leak is
almost always retention through something else — a listener never detached, a cache that only
grows, a static holding a screen. In the second it is a missing free or an ownership cycle. Six
rules cover both: an unreleased handle, missing cleanup on the error path, a subscription
outliving its owner, unbounded growth, retention through a longer-lived scope, and an ownership
cycle. It is told to trace every path out of a scope — early return, throw, cancellation,
`break` — because a release sitting on the happy path only is the most common leak there is and
is invisible on a single read.

Growth is not a leak; unbounded growth is. A cache with an eviction policy, a deliberate
process-lifetime singleton, a pool that reuses rather than releases, a buffer bounded by bounded
input, and test fixtures are all explicitly not findings, and where it cannot establish a bound
it is told to say so rather than assume one.

**The fix policy** is what makes an editing agent tolerable:

- The language's scoped-release construct is preferred over a hand-written release — it is the
  only form that survives an error path being added later.
- A removal is bound to the lifecycle event that created the registration, not bolted on
  wherever it fits.
- **Observable behaviour is never changed to make a finding go away.** It may not delete the
  acquisition, drop a feature, shorten a scope, or narrow what a cache holds.
- Where the fix needs a design change — ownership must move, or there is no lifecycle hook to
  hang a teardown on — it reports and leaves the code alone rather than inventing one.
- It works one file at a time, re-reads what it changed, and runs the repository's own test
  command if one is discoverable, reporting the result or saying it did not verify.

`tools` grants it `Edit` and not `Write`: every leak fix is a change to code that already
exists, so it has no reason to create a file, and withholding it removes a whole class of
surprise. `/leak-check --report-only` turns the editing off entirely, which is the mode to use
on a tree that already holds uncommitted work.

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

## `/design-review` and `/leak-check`

Both take a path or fall back to the uncommitted working tree, and both stop at the same
thirty-file threshold `/style-check` uses. Neither has a sweep to fall back on, because neither
question can be answered by measuring: a design finding needs the callers read alongside the
code, and a leak needs every path out of a scope traced. Past that size they say how large the
target is and ask which module to start from rather than degrading into a shallow pass.

`/design-review` never edits. It relays the agent's split between structural findings and
judgement calls without promoting one into the other, and where fixes are asked for afterwards
they are taken one finding at a time — the restructurings in a design report are rarely
independent of each other.

`/leak-check` edits unless `--report-only` is passed, and says so before it starts so the run
can be stopped if the tree is not in a state to be changed. Afterwards it shows the diff for
every file the agent touched. That is deliberate: a lifecycle change is exactly the kind of edit
that passes review by looking small, so the diff is the report.


## Adopting this on an existing codebase

Turning a 7-line cap on a mature project produces thousands of findings at once, almost none of
which are worth acting on in isolation. The intended order is:

1. **Let the hook do the work.** It only fires on files you actually write or edit, so the
   codebase converts as you touch it. For code you never open, the rules cost nothing.
2. **Sweep for triage** when you want to know where the damage is: `/style-check --sweep src`.
   It is free, so run it as often as you like.
3. **Review a hotspot** with `/style-check src/the-worst-file` to get rule 4, the judgement
   half of rule 5, and a concrete refactor, on one file at a time.
4. **Run `/design-review` on a module you are about to change**, not on the whole tree. Design
   findings are only actionable when you were going to open the code anyway.
5. **Run `/leak-check --report-only` first** on a codebase you have not seen before. Read what
   it finds, then re-run it without the flag on the part you are ready to have changed.

## The sweep script

`scripts/sweep.sh` measures a whole tree. It loads the same `hooks/lib/` modules the hooks do
rather than restating any of
them, so a sweep and a post-write advisory can never disagree about a cap. It puts the plugin's
`hooks/` directory on `sys.path` and imports the package by name.

```
sh scripts/sweep.sh <path> [--top N] [--strict]
```

`--top` caps the file listing (default 20) so a legacy repo does not dump thousands of lines.
`--strict` exits `1` when anything is found, which makes the same script usable as a CI gate;
the default exit is `0` because a report is not a failure.

File discovery uses `SOURCE` — the same set the hook measures, read through `scope.awk` — with `git ls-files` when
the target is in a repo, so `.gitignore` is respected for free, and a filesystem walk otherwise. Either way `SKIP_DIRS` drops
`node_modules`, `build`, `vendor`, and friends — vendored and generated code is often tracked,
so being in git is not enough to make something worth measuring.

The hook and the sweep now report the same findings; the hook caps its list at five per file
because it interrupts a write, while the sweep lists every one and is ordered by severity. That
shared measurement is what makes the totals trustworthy.
