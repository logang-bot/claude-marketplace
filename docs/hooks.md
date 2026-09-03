# Hooks

Hooks are the only part of a plugin that **executes on its own**. Skills, commands, and agents
are markdown instructions that shape what Claude does; a hook is a program the harness runs at a
fixed point in the loop, whether or not anyone asked.

All five here are POSIX shell for the glue and `awk` for anything that has to read code. They
read the hook payload as JSON on stdin and communicate back through their exit code — except
`inject-rules.sh`, which answers on stdout in JSON, because injecting context is not something
an exit code can express.

## Why shell and awk

The hooks used to be Python, and on a Windows machine with no Python installed **none of them
ran and nothing said so**. Two things went wrong at once, and the second is the one worth
remembering:

- Nothing guarantees a Python interpreter. Claude Code does not depend on one — nor on Node,
  whose npm package "installs the same native binary" and "does not itself invoke Node". A
  plugin that shells out to a language runtime is betting on a machine it never checked.
- The failure was invisible. A missing interpreter exits non-zero but not `2`, which the
  contract below treats as a non-blocking error, so the guard just quietly stopped guarding.

What every machine here does have is git. On Windows the standard git-scm.com installer provides
Git Bash — which Claude Code already prefers for hooks, falling back to PowerShell only when Git
Bash is absent — and with it a full MSYS2 userland including `awk`.

So the runtime dependency is now `awk` and `git`, plus the POSIX utilities that ship in the same
bundle — `sed`, `tr`, `sort`, `head`, `grep`, `cat`, `find`, `dirname`. `require_tools` checks
only `awk` and `git`, because those are the two whose absence is plausible; the rest arrive with
any shell that can run the script at all.

Write **POSIX awk only**: macOS ships BWK awk, so `gensub()`, `IGNORECASE`, `@include`, and
`asort()` are all out. Use `match()` + `substr()`, `split()`, and explicit counters.

## The exit-code contract

| Exit | Meaning |
|---|---|
| `0` | Silent. Allow whatever was about to happen. |
| `2` | Surface the stderr text. On `PreToolUse` this **blocks** the tool call; on `PostToolUse`, `PostToolBatch` and `Stop` the call already happened, so the text is advice. |
| anything else | **Non-blocking error.** The message may surface, but nothing is prevented. |

### Hooks fail open

That last row is the important one. A hook with a syntax error exits `1`, and exit `1` is a
non-blocking error — so a typo in `block-git-writes.sh` does not produce a loud failure. The
guard just silently stops guarding.

This is why `Check hook scripts parse` is a CI step: a hook that cannot run is
indistinguishable, in the moment, from a hook that decided to allow the command.

Every hook here degrades to silence rather than to noise on a **bad input**: each returns `0` on
malformed JSON, a missing file, or a non-git directory. A broken input should never block work.

**A missing dependency is the exception.** Each hook sources a `require_tools` helper that checks
`awk` (and `git` where it needs one) before doing anything, and on a miss prints what is missing
and exits `1` — deliberately claiming the non-blocking-error slot. `0` would repeat the original
bug by looking like a clean run; `2` on a `PreToolUse` hook would block every Bash call on a
machine that is merely missing a tool. Exit `1` puts the message in front of the user and gets
out of the way.

## Registration

Each plugin declares its hooks in `hooks/hooks.json`. The script path must go through
`${CLAUDE_PLUGIN_ROOT}`, which resolves to the installed plugin's directory — a relative path
would break, since the plugin runs from the cache, not from this repo:

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "shell": "bash",
          "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/block-git-writes.sh\"",
          "timeout": 10
        }
      ]
    }
  ]
}
```

`matcher` filters by tool name and accepts a regex alternation (`"Write|Edit"`). `Stop`,
`SubagentStart` and the other non-tool events take no matcher — there is no tool to match on.

**`PostToolBatch` is the trap.** It carries a whole batch of calls, and its matcher must match
**every** call in it, not any of them — so a matcher of `Write|Edit` silently skips a batch that
also held a `Read`. Filter inside the script instead; `check-size.sh` does, via `lib/batch.awk`.

`"shell": "bash"` is pinned on every hook here. Without it, a Windows machine with no Git Bash
would run the command through PowerShell, where a `sh` invocation means nothing.

### Line endings are load-bearing

Plugins install by git-clone into the plugin cache. On a machine with `core.autocrlf=true`, every
shipped script would arrive with CRLF endings and bash would fail on them with
`\r: command not found` — a fresh silent-hook failure of exactly the kind this migration exists
to end. The repo's `.gitattributes` pins `* text=auto eol=lf`, and the Windows CI job asserts no
CRLF survives a checkout.

---

## `block-git-writes.sh`

**Event:** `PreToolUse` · **Matcher:** `Bash` · **Timeout:** 10s · Plugin: `dev-workflow`

**Payload keys read:** `tool_name`, `tool_input.command`

The shell reads the payload and hands the command to `lib/git-rules.awk` on **stdin** — not
through `-v`, because awk expands escape sequences in a `-v` value and would rewrite backslashes
in the very command it is judging.

`git-rules.awk` splits the command on `&&`, `||`, `;` and `|`, two-character operators first so
`||` is never read as two empty pipes, then tests each segment. `gh` patterns are checked first,
on every segment. Git rules are only consulted for segments that actually start with `git`.

Matching is **anchored to the subcommand slot**. The Python original expressed that as one regex
with non-capturing groups; ERE has no equivalent, so `git_parts()` strips the leading `git` and
then consumes the global-option run in a loop:

```
-[cC] <value>              |  --git-dir=… / --work-tree … / --namespace / --exec-path  |  -<anything>
```

The global-option run is what lets `git -C /path <write>` be caught — without it, `-C` would be
mistaken for the subcommand. What remains begins with the subcommand, which is looked up in
`ALWAYS` (blocked outright) or handled by a predicate over the rest (`reset` only with `--hard`,
`tag` unless `-l`/`--list`, `checkout` only with `-b`/`-B`, and so on). `has_flag` understands
clustered short flags, so `clean -xdf` matches `-f`; only lowercase short flags cluster, so `-B`
and `-D` stay distinct.

Anchoring is not cosmetic. An earlier version matched patterns anywhere in the segment, which
denied read-only commands like `git log --grep=commit`.

### Testing it — put fixtures in a file

The hook scans the **entire Bash command string**. A test harness with a blocked command written
on the command line is itself a command containing that blocked command, so the installed hook
blocks your test run.

Keep fixtures in a script instead, assembled at runtime so they are inert on disk:

```sh
G=$(printf 'g%s' 'it')
must_block() {
cat <<EOF
$G push --force
EOF
}
```

An unquoted heredoc expands `$G` when the test runs, while the file on disk only ever contains
`$G push --force`.

Test both directions. A guard that blocks everything is as broken as one that blocks nothing.
The suite is `plugins/dev-workflow/tests/test_block_git_writes.sh`: 35 must-block and 34
must-pass cases. `test_docs_reminder.sh` next to it covers the reminder's classification.

---

## `docs-reminder.sh`

**Event:** `Stop` · **Timeout:** 15s · Plugin: `dev-workflow`

**Payload keys read:** `stop_hook_active`, `cwd`

Fires at the end of a turn when code changed but documentation did not. Exits `0` immediately —
doing nothing — when any of these hold:

- `stop_hook_active` is set. This means the hook already fired and Claude is stopping again;
  returning `2` here would loop forever.
- the working directory has no `docs/` folder. **This is why the hook was dormant in this repo
  until `docs/` was created.**
- git reports no changed files, or is unavailable. A repository with no commits counts here:
  `diff HEAD` fails without a HEAD, and the hook stops rather than guessing.

Changed files come from `git diff --name-only HEAD` plus
`git ls-files --others --exclude-standard`, and go to `lib/doc-rules.awk`, which prints each code
file and a single `__DOC__` marker if anything documentation-shaped changed. A file counts as
*code* if its extension is in `CODE` (Kotlin, Java, Swift, JS/TS, Python, Go, Rust, Ruby, PHP,
C#, C/C++, Scala, SQL) and as *docs* if it sits under `docs/` or carries a prose extension
(`.md`, `.mdx`, `.rst`, `.adoc`, `.txt`). The reminder fires only when there is code and no
`__DOC__`.

In this repo the practical effect is narrow: editing a hook without touching `docs/` triggers it;
editing a `SKILL.md` does not, because `.md` already counts as documentation.

---

## `check-size.sh`

**Event:** `PostToolBatch` · **No matcher** · **Timeout:** 10s · Plugin: `general-code-style`

**Payload keys read:** `tool_calls[].tool_name`, and the first of `tool_input.file_path`,
`notebook_path`, `path`, `filePath` at the same index that names a file that exists. Tools
disagree about what to call the target, and an MCP server that writes files picks its own name,
so the common spellings are all tried.

Measures everything the batch wrote and exits `2` with one advisory when a rule is broken. The
writes have already succeeded — the wording makes clear this is advice, not a rejection.

### Why the batch, not the call

`PostToolUse` fires per tool and runs **concurrently for parallel calls**, so five writes in one
block produced five separate hook processes, each printing its own advisory and each applying
`MAX_WARNINGS` on its own — the cap held five times over instead of once. `PostToolBatch` fires
once after every call in the batch has resolved, so the whole batch is measured together and the
cap means what it says. It is also where `advise.awk`'s `scope` earns its keep: the file is named
only when exactly one was measured, the same rule `check-new-files.sh` follows.

### The matcher is omitted deliberately

A `PostToolBatch` matcher must match **every** call in the batch, not any of them. With
`Write|Edit|MultiEdit|NotebookEdit`, a batch holding one `Read` beside a `Write` would skip the
hook entirely. So no matcher is set and the write-tool filter lives in `lib/batch.awk`, which
pairs each `tool_name` with the path at the same array index and keeps only the calls that
actually wrote. Without that filter the hook would measure a file that was merely **read**, which
is how an advisory becomes a nag.

### The risk worth naming

`PostToolBatch` is in the client's hook schema but has **no changelog entry anywhere in 2.x**. If
it turns out to be inert on some client, this check silently stops running — the exact failure
this whole migration exists to end. Two things blunt it: `check-new-files.sh` still catches every
**new** file at `Stop` regardless of event support, and the script still handles the single-call
payload shape, so re-registering it on `PostToolUse` restores the old behaviour with no code
change. The gap that would open in the meantime is narrow but real: **a modification to a file
that already exists**, which the `Stop` hook does not measure by design.

This hook only ever sees a write that **carries a path in its payload**. A heredoc, a `sed -i`,
or a generator script carries none, and no matcher can fix that — that gap is what
`check-new-files.sh` below exists to close.

---

## `check-new-files.sh`

**Event:** `Stop` · **Timeout:** 15s · Plugin: `general-code-style`

**Payload keys read:** `stop_hook_active`, `cwd`

The catch-all behind `check-size.sh`. That hook watches tool calls, so it only sees writes that
name a file in their payload. This one asks **git** at the end of the turn instead, which means
it does not care what did the writing — a Bash heredoc, a `sed -i`, a generator script, a
subagent, or an MCP server's own file-creation call all produce a file git can see.

It measures **only files git reports as new**:

- `git ls-files --others --exclude-standard` — untracked
- `git diff --name-only --diff-filter=A HEAD` — staged additions

Modifications are deliberately out of scope. Including them would mean re-reporting every
pre-existing violation in a dirty working tree on every single turn, which trains the reader to
ignore the advisory. The cost is real and worth naming: a shell command that **appends** to an
existing file is not caught here.

Paths are joined against `git rev-parse --show-toplevel`, deduplicated with `LC_ALL=C sort -u`
so the ordering is by byte and not by locale, and bounded by `MAX_FILES` (40) so the reading fits
inside the timeout. Findings are capped **once over the whole set** rather than per file, which
is why `advise.awk` takes a `scope` telling it whether naming one file would be honest.

It exits `0` on malformed JSON, on `stop_hook_active`, and outside a git repository. A repository
with **no commits** works: `diff HEAD` fails there and the untracked list alone is used.

Fixtures are in `plugins/general-code-style/tests/test_new_file_scan.sh`, which drives the hook
end to end against a scratch repository — `git init` alone exercises the untracked path. One test
asserts the diff query still carries `--diff-filter=A`, because dropping that flag is the
specific edit that would turn this hook into a nag.

The advisory closes by naming the `style-reviewer` agent and the files it should read. That is
not decoration. **No hook can launch an agent** — there is no such output field on any event —
and Claude Code's default posture suppresses spawning one unprompted, which is why the agents in
this plugin never fired on their own. Rules 1-3 and the comment rule are already measured above;
naming and doc comments that restate a name are not, because both need the code read rather than
counted. Naming the agent and the paths is the most a hook can do about it, and it makes
accepting the offer a single word instead of a round trip to reconstruct what to review.

---

## `inject-rules.sh`

**Event:** `SubagentStart` · **No matcher** · **Timeout:** 15s · Plugin: `general-code-style`

**Payload keys read:** none beyond a blankness check. The event carries `agent_id` and
`agent_type`; neither is consulted.

The only part of this repo that is **deterministic rather than advisory**. A subagent starts with
a fresh context and does no description matching against this plugin, so the skills that shape
how code gets written never reach it — its files were caught only afterwards, by
`check-new-files.sh`, once the work was done. This hook hands it the rules before it starts.

It answers on **stdout in JSON**, not through an exit code:

```json
{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"…"}}
```

`additionalContext` is the one channel that puts text into a subagent's context. The client caps
it at 8000 characters; `lib/jsonout.awk` truncates at 7000 **before** escaping, never after,
because cutting escaped output could sever a `\uXXXX` and produce a payload that will not parse.
Today's payload is around 3,700 characters.

The rules are read from the plugin's own `skills/*/SKILL.md` bodies at runtime, frontmatter
stripped, rather than restated in the script. One copy to keep right, and the directory is the
list — adding a skill adds it to the injection with no registration, which is how every other
component here is discovered. It is the same reason `limits.awk` holds the caps alone.

Injection is **unconditional**. Gating on `agent_type` would mean maintaining a list of names for
agents this plugin does not own, and such a list fails in the silent direction: a new writing
agent gets no rules and nothing says so. The cost is a couple of kilobytes spent on a read-only
agent like `Explore`.

Two limits worth knowing. The client **skips this injection entirely** for a subagent running
with an isolated context, and there is no signal here that it happened. And `SubagentStart`
landed in **2.0.43**, so unlike `PostToolBatch` it is well established.

Fixtures are in `plugins/general-code-style/tests/test_inject_rules.sh`. They check the envelope
structurally with `grep` rather than with a JSON parser, because these suites also run on Windows
Git Bash where nothing beyond `awk` and the POSIX utilities is guaranteed. Escaping is exercised
against `jsonout.awk` directly — driving it through the hook would only ever test the characters
that happen to be in a `SKILL.md` today.

---

## The measurement engine

Every number the style hooks report comes from `general-code-style/hooks/lib/`, a set of awk
modules loaded together with repeated `-f` flags — the portable way to keep a module structure in
awk:

```sh
awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" \
    -f "$LIB/blocks.awk" -f "$LIB/comments.awk" -f "$LIB/measure.awk" \
    -v path="$2" -v ext="$(extension_of "$2")" -- "$1"
```

| Module | Holds |
|---|---|
| `limits.awk` | The caps and the language sets. One definition, every consumer. |
| `text.awk` | String-literal blanking, comment markers, the allowed-comment list |
| `sizes.awk` | File length, body length, parameter counting |
| `blocks.awk` | Declaration matching and the span of the body each one opens |
| `comments.awk` | Explanatory comments found inside a body |
| `findings.awk` | Advisory wording |
| `measure.awk` | Emits one tab-separated record per finding |
| `advise.awk` | Records in, capped advisory out |
| `report.awk` | Records in, sweep report out |
| `scope.awk` | Filters a path list down to source files |
| `skip.awk` | Drops build output and dependency directories |
| `json.awk` | Scalars out of a hook payload, by dotted path; `all=1` for every match in an array |
| `jsonout.awk` | Text in, one line of `additionalContext` hook JSON out |
| `batch.awk` | Pairs tool names with paths in a batch, keeping only the calls that wrote |

`measure.awk` prints **records, not sentences**, because the hooks and the sweep need the same
numbers in different shapes:

```
FILE <path> <code lines>            LONG <path> <name> <line> <body>
WIDE <path> <name> <line> <params>  NOTE <path> <line> <text>
```

| Constant | Value | Meaning |
|---|---|---|
| `FILE_LIMIT` | 250 | 200 target + 50 spare, excluding import and `package` lines |
| `FUNCTION_LIMIT` | 10 | 7 target + 3 spare, body code lines only |
| `PARAM_LIMIT` | 3 | Parameters per declaration before the extras must be grouped into a type |
| `DECL_SPAN` | 12 | Lines a wrapped parameter list may span before it is given up on |
| `MAX_WARNINGS` | 5 | Advisories shown before the rest collapse into a count |
| `SOURCE` | allow-list | The one scope: what the hook measures and the sweep opens |

File length is measured for the extensions in `SOURCE`, and nothing else. That set is the
**single scope shared with the sweep** — `scope.awk` reads it too, so the two can never disagree
about whether something is in scope.

It is an allow-list rather than a deny-list because the sweep reads whole files: anything else
means walking a tree full of images, archives, and build output. Prose (`.md`, `.rst`, `.txt`)
and data (`.json`, `.yaml`, `.xml`, `.lock`) are absent on purpose: a long document is a
document, a long resource table is additive, and neither becomes harder to read at line 251.

Function length, parameter count, and the comment rule apply to `MEASURED` — the brace languages
plus Python. **Every** offender is reported, not just the worst one. Body length counts code
lines only: blank lines, lines opening with `//`, `#`, `*`, or `/*`, and a leading Python
docstring do not count, so documentation never eats into the budget.

Two strategies find a body, picked by extension. Brace languages balance `{`/`}` starting from
the brace that follows the closing `)` of the parameter list — not from the declaration line,
which is what used to make a wrapped multi-line signature measure a 0-line body. Python walks
indentation instead. Brace counting ignores braces inside string literals.

UI component functions are exempt from the size rules, detected by scanning the four lines above
a declaration for the UI markers. They are still recorded, carrying `FN_UI`, because the comment
rule applies to them.

The comment check reads only what is inside a body, so a licence banner, a file header, and a
doc comment above a declaration are out of scope by construction. Tool directives,
`TODO`/`FIXME`/`HACK`/`XXX` markers, and a Python docstring opening a body are allowed; a run of
consecutive comment lines is reported once rather than per line. String literals are blanked
before the search, so a `//` inside a URL is not a comment.

`general-code-style/scripts/sweep.sh` loads the same modules to measure a whole tree, and
`tests/probe.awk` loads them to print the raw measurements a fixture asserts on.

### Reading a payload without a JSON parser

`json.awk` walks the payload and prints the scalar at a dotted path (`tool_input.file_path`),
exiting `1` when the key is absent or the payload will not parse — every caller treats that as
"no value" rather than as an error.

Its unescaping is a **left-to-right scan, not a series of `gsub`s**, and that is not a style
preference. A Windows path arrives as `"C:\\new\\file"`, whose raw text contains a backslash
followed by `n`; any `gsub` that rewrites `\n` first would put a newline in the middle of a
directory name.

A path inside an array is addressed with `[]` — `tool_calls[].tool_name`. Without `all`, the last
match wins, which is the original single-value contract untouched. With `-v all=1`, every match
prints as `<index>\t<value>`, the index counting from 1 within the **nearest enclosing array**.
That index is the whole point: a batch's tool name and the file path it wrote sit under different
keys and are related only by their position, so `batch.awk` pairs them by index to decide which
paths belong to calls that actually wrote. A value containing a newline is dropped in this mode
rather than printed, because it would break the one-record-per-line pairing — losing a
measurement is recoverable, pairing a tool name against the wrong file is not.

`jsonout.awk` is the write side, and it escapes with the same left-to-right scan for the mirror
reason: each `gsub` pass rewrites the text the next one reads, so an earlier substitution can
manufacture the sequence a later one then mangles. Its `limit` truncates the raw text **before**
escaping — cutting escaped output could sever a `\uXXXX` and produce a payload that will not
parse.

---

## Adding a hook

1. Write the script under `plugins/<plugin>/hooks/`, reading JSON from stdin.
2. Source the plugin's `lib/engine.sh` or `lib/hook.sh` and call `require_tools` first, so a
   missing dependency is loud rather than silent.
3. Return `0` on every malformed or unexpected input, before doing any real work.
4. Register it in that plugin's `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` and
   `"shell": "bash"`.
5. Give it a `timeout`. A hook that hangs stalls the tool call.
6. Add fixtures covering both must-block and must-pass, per the pattern above.

`sh -n` is the floor, not the test — it proves the file parses, not that the logic is right, and
a hook that parses but misjudges will fail silently in the direction of allowing things.

Note that awk modules are parsed **per plugin, all at once** in CI rather than one file at a
time. A single module cannot see the functions its siblings define, and loading the set is also
what catches a name used as a function in one file and as a variable in another.
