# Testing and CI

## Before pushing

```bash
# Manifests parse and every marketplace entry points at a real plugin
for p in plugins/*/; do claude plugin validate "$p" --strict; done

# Hooks at least parse. awk modules load per plugin, not one at a time: a module alone
# cannot see the functions its siblings define.
for f in $(find plugins -name '*.sh'); do sh -n "$f"; done
for plugin in plugins/*/; do
  args=""; for m in $(find "$plugin" -name '*.awk' | sort); do args="$args -f $m"; done
  [ -n "$args" ] && awk $args </dev/null >/dev/null
done

# Hook logic still does what it claims to
for suite in plugins/*/tests/test_*.sh; do sh "$suite"; done

# No plugin has been tied back to one project or the old owner
grep -rniE 'restrusher|in this project we|domain/usecase/' \
  --include='*.md' --include='*.json' --include='*.sh' --include='*.awk' \
  .claude-plugin plugins README.md
```

The last one should print nothing. It is the check that keeps the plugins portable, and it is
the easiest to violate by pasting a real example without stripping its `package` line.

It deliberately does **not** scan `docs/` or `.github/`. Both describe the rule, so both contain
the words it looks for — scanning them would report the documentation of the guard as a
violation of it.

## Testing hooks

Hooks are the only executable part of the repo, and the only part that can fail silently in the
permissive direction — see [hooks.md](hooks.md#hooks-fail-open). `sh -n` proves a file parses;
it proves nothing about whether the logic is right.

Test with fixtures kept **in a file**, driving the hook's own awk modules rather than
re-implementing their logic in the harness:

```sh
G=$(printf 'g%s' 'it')
must_block() {
cat <<EOF
$G push --force
EOF
}
```

The reason fixtures live in a file rather than on the command line: `block-git-writes.sh` scans
the entire Bash command string, so a harness that spells a blocked command out as an argument
*is* a command containing it, and the installed hook blocks the test run. An unquoted heredoc
expands `$G` only when the test runs, so the file on disk stays inert.

Always test both directions. `plugins/dev-workflow/tests/test_block_git_writes.sh` is 35
must-block and 34 must-pass cases; the must-pass half is what caught the anchoring bug, where
read-only commands like `git log --grep=commit` were being denied, and it is what made the
guard safe to refactor. `test_docs_reminder.sh` covers the reminder's file classification.

`plugins/general-code-style/tests/test_style_rules.sh` covers the size and comment measurements
through `tests/probe.awk`, a test-only driver that prints the measurements themselves rather than
the sentences they become, so a fixture asserts on a body length directly. Its must-pass half is
the load-bearing one: a comment check that flags `TODO`, a licence header, a `//` inside a URL,
or a Python docstring would make the hook unusable noise, and a parameter counter that miscounts
a trailing comma or a `Map<String, Int>` invents findings that are not there.

## What `validate.yml` checks

Runs on every push and pull request, in two jobs: `manifests` on `ubuntu-latest` and `windows` on
`windows-latest`.

The runner may use whatever it likes — the manifest and frontmatter validators are Python, which
GitHub provides. **The shipped plugins may not.** That distinction is the whole point of the
migration: a check that runs on a CI runner has a guaranteed toolchain, and a hook on a
contributor's laptop does not.

| Step | Catches |
|---|---|
| Validate JSON syntax | A trailing comma or unclosed brace in any manifest or `hooks.json` |
| Check every marketplace source path exists | An entry pointing at a missing folder, or a `name` that disagrees with the plugin's manifest |
| Check skill frontmatter | A `SKILL.md` with no frontmatter block, or missing `name` / `description` |
| Check skill directory names match frontmatter | A skill folder renamed without updating `name:` |
| Check command and agent frontmatter | A command or agent with no `description` |
| Check hook scripts parse | A shell or awk syntax error, and a name used as a function in one module and a variable in another |
| Run the hook tests | A guard or a measurement that silently stops working |
| Check for project-specific leakage | `restrusher`, "in this project we", or `domain/usecase/` creeping back in |

Every one of these is a failure that produces **no error at runtime**. A skill with broken
frontmatter does not crash — it silently never loads, in every project that installed the
plugin, and you notice weeks later when a convention stops firing for no visible reason. The
workflow turns that into a red ✗ thirty seconds after you push.

### The Windows job

`windows-latest` runs the same parse checks and test suites under Git Bash — the same shell
Claude Code picks for hooks on a Windows machine that has git. Nothing else proves the plugins
work there, and three failures show up on Windows and nowhere else:

- a `core.autocrlf` checkout handing bash a script with CRLF endings, which fails with
  `\r: command not found`. A dedicated step asserts no CRLF survives the checkout, backing up
  the `eol=lf` pin in `.gitattributes`.
- a path arriving with backslashes and a drive letter.
- an `awk` that is missing from the Git Bash install. The job prints `awk --version` before
  anything else, so a change in what Git for Windows bundles surfaces as a specific failure
  rather than as a mysterious one.

## <a id="ci-is-a-report-not-a-gate"></a>CI is a report, not a gate

Worth being clear about the limits:

- `git push` completes **before** the workflow starts. A red ✗ cannot reject a commit or roll
  anything back.
- Nothing in the plugin update path consults CI status. When a consumer refreshes, they get
  whatever is on the default branch — green, red, or never run.

So the workflow notifies you; it does not quarantine anything. What delays exposure is
[pinning](architecture.md#installation-pinning-and-updates), and pinning is a cache, not a
safety net — it does nothing for a fresh install on a new machine.

**If you want a real gate**, that is a GitHub setting rather than a file change: protect the
default branch, require the `validate` check to pass, and land changes through pull requests.
Then the default branch only ever holds validated state, and there is no broken commit for a
consumer to pin to.

## Release checklist

1. Make the change; run the checks above.
2. Bump `version` in each changed plugin's `plugin.json` — the install cache is keyed by it, so
   without a bump installed clients have no signal to refetch.
3. Update the affected page under [`plugins/`](plugins/), and sweep the other docs for claims the
   change made stale.
4. Commit and push yourself. The `dev-workflow` hook blocks Claude from doing it, deliberately.
5. Confirm the run is green in the repo's Actions tab.
