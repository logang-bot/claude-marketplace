#!/bin/sh
# Fixtures for what the Stop hook measures, as opposed to when it measures it.
#
# The hook is driven end to end against a scratch repository rather than having git stubbed
# out: `git init` alone is enough to exercise the untracked path, which is the one that catches
# a file a shell command created.
#
# Turn scoping — which files count as this turn's work — lives in test_turn_scope.sh. Here the
# turn is primed through the prompt hook so that every file is unambiguously the turn's work,
# and what is under test is the filtering, the capping and the guards.
#
# Both directions matter. A scan that measured every file in the tree would nag about
# pre-existing violations, which is as broken as one that measured nothing.
#
# Run: sh plugins/general-code-style/tests/test_new_file_scan.sh

set -u
HERE=$(dirname "$0")
PROMPT_HOOK=$HERE/../hooks/snapshot-turn.sh
HOOK=$HERE/../hooks/check-new-files.sh
LIB=$HERE/../hooks/lib
WORK=${TMPDIR:-/tmp}/new-file-scan-test.$$
FAILURES=0

TMPDIR=$WORK/state
export TMPDIR

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/repo/src" "$WORK/state"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

payload() { printf '{"session_id":"n1","cwd":"%s","prompt_id":"%s"}' "$WORK/repo" "$1"; }
begin_turn() { payload "$1" | sh "$PROMPT_HOOK" >/dev/null 2>&1; }
run_hook() { payload "$1" | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?"; }
advisory_of() { payload "$1" | sh "$HOOK" 2>&1 >/dev/null; }

oversized_kotlin() {
    printf 'package a.b\n\n'
    n=0
    while [ "$n" -lt 300 ]; do
        printf 'val line%s = %s\n' "$n" "$n"
        n=$((n + 1))
    done
}

git -C "$WORK/repo" init -q .

# --- nothing new yet ---------------------------------------------------------

begin_turn a0
check "an empty repository is silent" "$(run_hook a0)" "0"

# --- a file no Write tool ever touched ---------------------------------------

begin_turn a1
oversized_kotlin > "$WORK/repo/src/Big.kt"
printf 'a\n%.0s' $(seq 1 400) > "$WORK/repo/notes.md"
: > "$WORK/repo/art.png"

check "an untracked oversized source file is caught" "$(run_hook a1)" "2"

advisory=$(advisory_of a1)
check "the source file is named" \
    "$(printf '%s' "$advisory" | grep '^- ' | grep -c 'src/Big.kt' | tr -d ' ')" "1"
check "prose is not measured" \
    "$(printf '%s' "$advisory" | grep -c 'notes.md' | tr -d ' ')" "0"
check "binaries are not measured" \
    "$(printf '%s' "$advisory" | grep -c 'art.png' | tr -d ' ')" "0"

# The wording has to order the fix rather than describe the finding; an agent that reads this
# as optional is the failure that prompted the rewrite.
check "the wording orders the fix" \
    "$(printf '%s' "$advisory" | grep -c 'required fix' | tr -d ' ')" "1"
check "the agent is offered by name for what is not measured" \
    "$(printf '%s' "$advisory" | grep -c 'style-reviewer' | tr -d ' ')" "1"
check "the offer names the offending file" \
    "$(printf '%s' "$advisory" | grep 'style-reviewer' | grep -c 'src/Big.kt' | tr -d ' ')" "1"

# --- only files that broke a rule are named ----------------------------------

# measure.awk emits a FILE record for every file it measures, so a consumer that reads $2 off
# every record names the clean ones too. That shipped in 0.8.0 and listed five files for one
# violation.
begin_turn a2
oversized_kotlin > "$WORK/repo/src/Huge.kt"
for name in Clean1 Clean2 Clean3 Clean4; do
    printf 'package a.b\n\nclass %s\n' "$name" > "$WORK/repo/src/$name.kt"
done
trailer=$(advisory_of a2 | grep 'style-reviewer')
check "a clean file is not named for review" \
    "$(printf '%s' "$trailer" | grep -c 'Clean1.kt' | tr -d ' ')" "0"
check "the offender still is" \
    "$(printf '%s' "$trailer" | grep -c 'Huge.kt' | tr -d ' ')" "1"

# --- the guards that keep it from looping or nagging -------------------------

check "a second stop in the same turn is silent" \
    "$(payload a2 | sed 's/}$/,"stop_hook_active":true}/' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" \
    "0"
check "a malformed payload is silent" \
    "$(printf 'not json' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "an empty payload is silent" \
    "$(printf '' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "outside a repository is silent" \
    "$(printf '{"cwd":"/usr"}' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"

check "untracked respects .gitignore" \
    "$(grep -c -- '--exclude-standard' "$LIB/turn.sh" | tr -d ' ')" "1"
# Modifications are in scope on purpose now: --diff-filter=A used to exclude them, which meant
# a file the agent had just changed was never measured. test_turn_scope.sh covers the
# behaviour; this pins the query that makes it possible.
check "tracked changes are queried, not just additions" \
    "$(grep -c -- 'diff --name-only HEAD' "$LIB/turn.sh" | tr -d ' ')" "1"
check "additions are no longer filtered out of the diff" \
    "$(grep -c -- '--diff-filter=A' "$LIB/turn.sh" | tr -d ' ')" "0"

# --- scope, shared with the sweep --------------------------------------------

kept=$(printf 'src/Big.kt\nnotes.md\nart/icon.png\nsrc/small.py\n\n' \
    | awk -f "$LIB/limits.awk" -f "$LIB/scope.awk" | tr '\n' ' ' | sed 's/ $//')
check "only source files survive the filter" "$kept" "src/Big.kt src/small.py"

# --- findings are capped once over the whole set -----------------------------

begin_turn a3
n=0
while [ "$n" -lt 8 ]; do
    printf 'package a.b\n\nfun f%s(a: Int, b: Int, c: Int, d: Int) {\n    val x = a\n}\n' \
        "$n" > "$WORK/repo/src/Wide$n.kt"
    n=$((n + 1))
done
lines=$(advisory_of a3 | grep -c '^- ')
check "one cap over the whole set, not one per file" "$lines" "6"
check "the overflow line does not claim one file" \
    "$(advisory_of a3 | grep -c 'more findings in this file' | tr -d ' ')" "0"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
