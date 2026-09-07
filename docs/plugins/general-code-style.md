# `general-code-style`

Language-agnostic rules for how big things are allowed to get and how clearly they must be
named. Nothing in it is tied to a platform, a framework, or a build system.

**Install it everywhere.** It is the base layer; platform plugins add to it rather than
restating it.

## Components

| Kind | Name | Fires when |
|---|---|---|
| Skill | `creating-files-or-classes` | A file or class is being created, or a member is placed in one |
| Skill | `creating-methods-or-functions` | A method or function is being written |
| Agent | `style-reviewer` | Asked to check style, or after a batch of new code |
| Agent | `senior-reviewer` | Asked for a design or architecture review, or before a refactor |
| Agent | `leak-hunter` | Asked about leaks, or after code that acquires a resource |
| Command | `/style-check [path] [--sweep] [--dirty]` | Run explicitly |
| Command | `/design-review [path]` | Run explicitly |
| Command | `/leak-check [path] [--report-only]` | Run explicitly |
| Hook | `SubagentStart` | A subagent starts — hands it the rules its context does not carry |
| Hook | `UserPromptSubmit` in plan mode | A planning turn begins — hands the main thread the caps |
| Hook | `PreToolUse` on `ExitPlanMode\|Skill` | A plan is accepted, or a brainstorming skill runs |
| Hook | `PreToolUse` on a write tool | The first write of a session — the last moment before code exists |
| Hook | `UserPromptSubmit` | Snapshots the tree and its findings, so the checks can scope themselves to the request |
| Hook | `PostToolBatch` | After a batch of writes, over the files that named a path |
| Hook | `Stop` | At each yield, over the files git reports the request worked on |
| Script | `scripts/sweep.sh` | Via `/style-check` on a large target, or run directly |
| Modules | `hooks/lib/*.awk` | Loaded by the hooks, the sweep, and the tests |
| Tests | `tests/test_*.sh` | In CI, and before pushing a measurement change |

## The size, order, and naming rules

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


## Member order

A type reads top to bottom, so where a member sits is part of how it reads. Three rules fix it,
and they are stated as one so they cannot drift apart:

| Rule | What it says |
|---|---|
| Blocks | Properties, then constructors, then methods. Never a property between two methods. |
| Visibility tiers | Inside each block: public, then internal, then protected, then private. |
| Call order | Inside each tier: a helper directly below its caller, depth first. |

The third one exists because of the second cap on this page. A ~7-line body cap manufactures
small private helpers by design, and with nothing saying where they go they land in the order
they were typed — so a class becomes a bag of helpers and the reader has to search for the one
that matters. Depth first means that if `submit()` calls `a()` and then `b()`, and `a()` calls
`a1()`, the order is `submit, a, a1, b`: each helper's own subtree finishes before its sibling
begins.

Visibility and call order look like they contradict each other — one wants the private helper at
the bottom, the other wants it directly under its caller — and the split is what settles it.
**Visibility decides the block; call order decides the sequence inside the block.** A class ends
up with its public API gathered at the top and a private block below that still reads top-down.

**The first two are measured. The third never is.** Call order needs a call graph, and this
engine reads lines rather than syntax: it cannot tell `this.charge()` from `gateway.charge()`, or
a method name inside a string literal from a call to it. A guessed graph would invent findings,
and on this page an invented finding costs more than a missed one — so the rule ships in the
skills and in `style-reviewer`, and `members.awk` does not attempt it.

Two shapes are explicitly not findings, because a check that fires on them is a check nobody
reads:

- **The backing-property pair.** `private val _state` followed by `val state = _state.asStateFlow()`
  is public-after-private on purpose, and it is the most common shape in the stack this
  marketplace ships beside. A property that references a more restricted one declared directly
  above it is the same member exposed, not a member out of order. The test asserts identifier
  matching rather than substring matching, so `val b = 2` is not read as a reference to a
  property called `a`.
- **A constructor between the fields and the methods.** `typed_name()` already matches
  `public Foo(int a) {`, so without constructor classification every field below a constructor
  would be reported. Member classification recognises one by its name matching the enclosing
  type, or by `constructor` / `init` / `__construct` / `__init__`.

A Kotlin `companion object` at the bottom of a class is quiet for a structural reason rather
than a carve-out: nested blocks are stepped over whole, so its contents are never examined and
never mixed into the parent's member list. The same is true of a nested class.

Member order is **ordered** rather than reported — moving a declaration is local, mechanical, and
complete at the write, which is the same test function length and parameter count pass.

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

## The rules arrive before the code, not only after it

Two of the hooks **inject** rather than measure. Every other component here is advisory —
a skill fires if its description matches, an agent runs if someone asks for it — and
description matching is probabilistic. Injection is not.

- `hooks/inject-rules.sh` (`SubagentStart`) hands the rules to every subagent, which starts
  with a fresh context and matches no descriptions at all.
- `hooks/inject-plan-rules.sh` covers **the main thread**, which does most of the writing and had
  no deterministic injection before. It sends the caps as design constraints when a planning turn
  begins (`UserPromptSubmit` with `permission_mode` of `plan`) or a brainstorming skill runs, the
  full rules at the handoff into implementation (`PreToolUse` on `ExitPlanMode`), and the full
  rules again before the **first write of any session** — which is what covers an ordinary turn
  that never plans anything, and that is most of them.

The point is where the correction is cheapest. Measuring after the fact is correct, but it is
paid for in rework: a 300-line file gets written, measured, and then split. Before the file
exists there is nothing to refactor, so the same correction costs a paragraph.

Injection carries more weight than it used to. A file over the line cap is **reported** rather
than ordered, so prevention is the only thing actually keeping files small — see the size hooks
below. The digest is sent once per planning episode; the full rules once per session, whichever
trigger gets there first. See [../hooks.md](../hooks.md) for the triggers, the two markers, and
the client-support risk.

## The size hooks

`hooks/check-size.sh` runs after every batch of writes that name a file; `hooks/check-new-files.sh`
runs at the end of a turn and asks git instead, so it catches writes no tool payload described —
a heredoc, a `sed -i`, a generator script, an MCP server. Both answer on stdout with
`additionalContext`, which reaches the model as feedback; neither blocks anything, and neither is
rendered as an error.

They check five things: file length, function body length, parameter count, member
declaration order, and comments that explain code inside a function body. **Two rules
govern how each one is delivered.**

**Only what the turn introduced is reported.** A violation that was already in the file before the
work started is not the turn's to answer for. Editing one line of a file that has been 300 lines
for months says nothing at all — that scope explosion is what used to send an agent off to
refactor code nobody asked it to touch.

**The cost of the fix decides whether it is an order or a report.** Function length, parameter
count and comments are local: they are complete the moment the function is written, and fixing one
is an extraction inside a file still in hand. Those are ordered, at the write. File length is
neither knowable mid-turn nor cheap to fix, so it is **reported to the user** — the size is stated
and the decision to split is theirs. Anything left over the cap is re-surfaced until it is fixed
or the turn hands back, and `scripts/sweep.sh --dirty` lists what is still uncommitted and over
the cap at any time.

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
| `MEASURED` | `BRACE` (Kotlin/`.kts`, Java, JS/TS, Swift, C/C++, C#, Go, Rust, Scala, PHP, Dart, Gradle, Groovy) plus Python | Size, parameters, comments |
| `FILE_ONLY` | Ruby, shell, awk, SQL, Obj-C, `.vue`, `.svelte`, Lua, Perl, R, Julia, Elixir, Erlang, Haskell, Clojure, Terraform, and friends | File length only |
| `ORDERED` | Kotlin/`.kts`, Java, C#, TS/TSX, Swift, PHP, Scala | Member order, on top of those |
| `SOURCE` | The union of `MEASURED` and `FILE_ONLY` | The scope of both the hook and the sweep |

`ORDERED` is a subset of `MEASURED` rather than a fourth tier. Every ordering check reads a
visibility keyword off a declaration, so a language that has none cannot be measured honestly:
JS/JSX, Go and Dart have no visibility keywords, Rust puts `pub` on items inside an `impl`
block, the C family uses `public:` section labels — a different shape entirely — and Python has
only the leading-underscore convention. TypeScript needs one extra thing: its class methods
carry no declaration keyword, so `decl_name()` cannot see them and `typed_name()` is never
consulted for a `KEYWORD` language. `IMPLICIT_METHOD` names the extensions where the member walk
recognises them itself, which is safe only because it runs at depth 1 of a type body, where a
control-flow line cannot appear.

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
is told to be firm on rules 1–3 and 6 because they are mechanical, but to raise the naming,
comment, and call-order rules only when it can name what a reader would actually
misunderstand, or the rename that would remove the need for the comment. It is explicitly
instructed not to manufacture findings to fill a report.

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
| No path — the uncommitted working tree | Agent review | All seven |
| A path of 30 files or fewer | Agent review | All seven |
| A path over 30 files | Sweep | 1–3 and 6, plus in-body comments |
| `--sweep <path>` | Sweep, at any size | 1–3 and 6, plus in-body comments |

The threshold exists because the agent *reads* code, and reading is what costs. Past roughly
thirty files it exhausts its context before finishing, so the command measures instead.

Sweep mode states explicitly what it did not evaluate: **naming**, **call order**, and
whether a doc comment says something its member's name already says. Those three need a
judgement about what a reader would misunderstand, which is not a thing a script can
measure. The rest of rule 5 — a comment that narrates code inside a body — is mechanical,
and is measured, as is member order in the `ORDERED` languages.

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
rather than restating any of them, so a sweep and a post-write advisory can never disagree about
a cap.

```
sh scripts/sweep.sh <path> [--top N] [--strict] [--dirty]
```

`--top` caps the file listing (default 20) so a legacy repo does not dump thousands of lines.
`--strict` exits `1` when anything is found, which makes the same script usable as a CI gate;
the default exit is `0` because a report is not a failure.

`--dirty` narrows the sweep to files that differ from `HEAD`, tracked or untracked — the same
pair `lib/turn.sh` reads the tree through. It exists because the hooks **report** a file over the
line cap rather than ordering a split, so an unfixed one stays in the working tree, and that
makes "uncommitted and over the cap" a precise definition of outstanding style debt. It is the
check to run before a commit, and `--strict --dirty` is the same thing as a pre-commit gate. It
needs a git repository and says so if there is none.

File discovery uses `SOURCE` — the same set the hook measures, read through `scope.awk` — with `git ls-files` when
the target is in a repo, so `.gitignore` is respected for free, and a filesystem walk otherwise. Either way `SKIP_DIRS` drops
`node_modules`, `build`, `vendor`, and friends — vendored and generated code is often tracked,
so being in git is not enough to make something worth measuring.

The hooks and the sweep measure the same things, but answer different questions. A hook reports
only what the current request introduced, and caps its list at five because it interrupts work;
the sweep reports everything it finds, ordered by severity, because it was asked to. That shared
measurement is what makes the totals trustworthy — and it is why the sweep, not the hooks, is
where you go to ask what the whole tree looks like.
