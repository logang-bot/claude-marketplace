# Hooks

Hooks are the only part of a plugin that **executes on its own**. Skills, commands, and agents
are markdown instructions that shape what Claude does; a hook is a program the harness runs at a
fixed point in the loop, whether or not anyone asked.

All three here are Python 3 with no third-party dependencies. They read the hook payload as JSON
on stdin and communicate back through their exit code.

## The exit-code contract

| Exit | Meaning |
|---|---|
| `0` | Silent. Allow whatever was about to happen. |
| `2` | Surface the stderr text. On `PreToolUse` this **blocks** the tool call; on `PostToolUse` and `Stop` the call already happened, so the text is advice. |
| anything else | **Non-blocking error.** The message may surface, but nothing is prevented. |

### Hooks fail open

That last row is the important one. A hook with a syntax error exits `1`, and exit `1` is a
non-blocking error — so a typo in `block-git-writes.py` does not produce a loud failure. The
guard just silently stops guarding, and git writes start going through again.

This is why `Compile hook scripts` is a CI step: a hook that cannot run is indistinguishable, in
the moment, from a hook that decided to allow the command.

Every hook here is written to degrade to silence rather than to noise: each returns `0` on
malformed JSON, a missing file, or a non-git directory. A broken *input* should never block
work — only a real violation should.

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
          "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/block-git-writes.py\"",
          "timeout": 10
        }
      ]
    }
  ]
}
```

`matcher` filters by tool name and accepts a regex alternation (`"Write|Edit"`). `Stop` takes no
matcher — there is no tool to match on.

---

## `block-git-writes.py`

**Event:** `PreToolUse` · **Matcher:** `Bash` · **Timeout:** 10s · Plugin: `dev-workflow`

**Payload keys read:** `tool_name`, `tool_input.command`

Splits the command on `&&`, `||`, `;` and `|`, then tests each segment. `gh` patterns are checked
first, on every segment. Git rules are only consulted for segments that actually start with
`git`.

Matching is **anchored to the subcommand slot**:

```
^\s*(?:sudo\s+)?git\s+(?:(?:-[cC]\s+\S+|--(?:git-dir|work-tree|…)(?:=\S*|\s+\S+)|-\S+)\s+)*([\w-]+)\b(.*)$
```

The global-option run is what lets `git -C /path commit` be caught — without it, `-C` would be
mistaken for the subcommand. The captured subcommand is looked up in a table where each entry is
either blocked outright, or blocked conditionally by a predicate over the rest of the command
(`reset` only with `--hard`, `tag` unless `-l`/`--list`, `checkout` only with `-b`/`-B`, and so
on). `has_flag` understands clustered short flags, so `clean -xdf` matches `-f`.

Anchoring is not cosmetic. The earlier version matched patterns anywhere in the segment, which
denied read-only commands like `git log --grep=commit`.

### Testing it — put fixtures in a file

The hook scans the **entire Bash command string**. A test harness with `git commit` written on
the command line is itself a command containing `git commit`, so the installed hook blocks your
test run.

Keep fixtures in a script instead, and import the hook rather than shelling out:

```python
import importlib.util
spec = importlib.util.spec_from_file_location("hook", "plugins/dev-workflow/hooks/block-git-writes.py")
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)

G = "g" + "it"          # keeps the fixture out of any command line that quotes this file
assert hook.find_violation(f"{G} checkout -B main") is not None
assert hook.find_violation(f"{G} log --grep=commit") is None
```

Test both directions. A guard that blocks everything is as broken as one that blocks nothing —
the current suite is 24 must-block and 25 must-pass cases.

---

## `docs-reminder.py`

**Event:** `Stop` · **Timeout:** 15s · Plugin: `dev-workflow`

**Payload keys read:** `stop_hook_active`, `cwd`

Fires at the end of a turn when code changed but documentation did not. Exits `0` immediately —
doing nothing — when any of these hold:

- `stop_hook_active` is set. This means the hook already fired and Claude is stopping again;
  returning `2` here would loop forever.
- the working directory has no `docs/` folder. **This is why the hook was dormant in this repo
  until `docs/` was created.**
- git reports no changed files, or is unavailable.

Changed files come from `git diff --name-only HEAD` plus
`git ls-files --others --exclude-standard`. A file counts as *code* if its extension is in
`CODE_EXT` (Kotlin, Java, Swift, JS/TS, Python, Go, Rust, Ruby, PHP, C#, C/C++, Scala, SQL) and
as *docs* if it sits under `docs/` or has a `DOC_EXT` extension (`.md`, `.mdx`, `.rst`, `.adoc`,
`.txt`). The reminder fires only when there is code and no docs.

In this repo the practical effect is narrow: editing a hook `.py` without touching `docs/`
triggers it; editing a `SKILL.md` does not, because `.md` already counts as documentation.

---

## `check-size.py`

**Event:** `PostToolUse` · **Matcher:** `Write|Edit` · **Timeout:** 10s · Plugin:
`general-code-style`

**Payload keys read:** `tool_input.file_path`

Measures the file that was just written and exits `2` with an advisory when a cap is exceeded.
The write has already succeeded — the wording makes clear this is advice, not a rejection.

| Constant | Value | Meaning |
|---|---|---|
| `FILE_LIMIT` | 250 | 200 target + 50 spare, excluding import and `package` lines |
| `FUNCTION_LIMIT` | 15 | 10 target + 5 spare, body lines only |

File length is measured for any file type. Function length only for `BRACE_LANGS`, and only the
longest top-level function is reported. UI component functions are exempt, detected by scanning
the four lines above a declaration for `UI_MARKERS` — see
[plugins/general-code-style.md](plugins/general-code-style.md#the-ui-component-exemption) for the
declaration-matching details.

Note that `MultiEdit` and `NotebookEdit` are not in the matcher, so writes through those paths
are unmeasured.

---

## Adding a hook

1. Write the script under `plugins/<plugin>/hooks/`, reading JSON from stdin.
2. Return `0` on every malformed or unexpected input, before doing any real work.
3. Register it in that plugin's `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}`.
4. Give it a `timeout`. A hook that hangs stalls the tool call.
5. Add fixtures covering both must-block and must-pass, per the pattern above.

`python3 -m py_compile` is the floor, not the test — it proves the file parses, not that the
logic is right, and a hook that parses but misjudges will fail silently in the direction of
allowing things.
