#!/bin/sh
# Fixtures for what the Stop hook measures, as opposed to when it measures it.
#
# The hook is driven end to end against a scratch repository rather than having git stubbed out:
# `git init` alone is enough to exercise the untracked path, which is the one that catches a file
# a shell command created and no tool payload ever named.
#
# Request scoping — which files count as this request's work — lives in test_turn_scope.sh. Here
# the request is primed through the prompt hook so that every file is unambiguously its work, and
# what is under test is the filtering, the capping, the routing and the guards.
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

payload() { printf '{"session_id":"n1","cwd":"%s","prompt_id":"%s","prompt":"go"}' "$WORK/repo" "$1"; }
begin_turn() { payload "$1" | sh "$PROMPT_HOOK" >/dev/null 2>&1; }

# The hook records what it has said, so a scenario is run once and asserted against afterwards.
# RUN_ERR is captured too: a style finding must never reach stderr, which is what made the old
# version render as "Stop hook error".
run_hook() {
    RUN_ERR=$(payload "$1" | sh "$HOOK" 2>&1 >"$WORK/out.json")
    RUN_STATUS=$?
    RUN_OUT=$(cat "$WORK/out.json")
    RUN_TEXT=$(printf '%s' "$RUN_OUT" \
        | awk -f "$LIB/json.awk" -v key=hookSpecificOutput.additionalContext)
}

oversized_kotlin() {
    printf 'package a.b\n\n'
    _i=0
    while [ "$_i" -lt 300 ]; do
        printf 'val line%s = %s\n' "$_i" "$_i"
        _i=$((_i + 1))
    done
}

git -C "$WORK/repo" init -q .

# --- nothing new yet ---------------------------------------------------------

begin_turn a0
run_hook a0
check "an empty repository is silent" "$RUN_STATUS" "0"
check "and says nothing" "$RUN_OUT" ""

# --- a file no Write tool ever touched ---------------------------------------

begin_turn a1
oversized_kotlin > "$WORK/repo/src/Big.kt"
printf 'a\n%.0s' $(seq 1 400) > "$WORK/repo/notes.md"
: > "$WORK/repo/art.png"
run_hook a1

check "a file only git can see is caught" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'src/Big.kt' | tr -d ' ')" "1"
check "the answer is feedback, not a failure" "$RUN_STATUS" "0"
check "nothing goes to stderr" "$RUN_ERR" ""
check "the answer is JSON the client can read" \
    "$(printf '%s' "$RUN_OUT" | grep -c '"hookEventName":"Stop"' | tr -d ' ')" "1"
check "prose is not measured" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'notes.md' | tr -d ' ')" "0"
check "binaries are not measured" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'art.png' | tr -d ' ')" "0"

# File size is the finding that used to stall a turn. It is now handed to the user.
check "file size is routed to the user" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'for the user rather than for you' | tr -d ' ')" "1"
check "and asks to be said in the summary" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'Say this in your summary' | tr -d ' ')" "1"
check "it never orders a split" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'Split it into' | tr -d ' ')" "0"
check "and the excuse-refusing clause is gone with it" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'not a reason to skip it' | tr -d ' ')" "0"
check "what is not measured points at the command, not an agent to spawn" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'style-check' | tr -d ' ')" "1"

# --- only files that broke a rule are named ----------------------------------

# measure.awk emits a FILE record for every file it measures, so a consumer that reads $2 off
# every record names the clean ones too. That shipped in 0.8.0 and listed five files for one
# violation.
begin_turn a2
oversized_kotlin > "$WORK/repo/src/Huge.kt"
for name in Clean1 Clean2 Clean3 Clean4; do
    printf 'package a.b\n\nclass %s\n' "$name" > "$WORK/repo/src/$name.kt"
done
run_hook a2
check "a clean file is never named" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'Clean1.kt' | tr -d ' ')" "0"
check "the offender is" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'Huge.kt' | tr -d ' ')" "1"

# --- the guards that keep it from looping or nagging -------------------------

check "a stop inside another hook's continuation is silent" \
    "$(payload a2 | sed 's/}$/,"stop_hook_active":true}/' | sh "$HOOK" 2>/dev/null)" ""
check "a malformed payload is silent" \
    "$(printf 'not json' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "an empty payload is silent" \
    "$(printf '' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "outside a repository is silent" \
    "$(printf '{"cwd":"/usr"}' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"

check "untracked respects .gitignore" \
    "$(grep -c -- '--exclude-standard' "$LIB/turn.sh" | tr -d ' ')" "1"
# Modifications are in scope on purpose: --diff-filter=A used to exclude them, which meant a file
# the agent had just changed was never measured.
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
_n=0
while [ "$_n" -lt 8 ]; do
    printf 'package a.b\n\nfun f%s(a: Int, b: Int, c: Int, d: Int) {\n    val x = a\n}\n' \
        "$_n" > "$WORK/repo/src/Wide$_n.kt"
    _n=$((_n + 1))
done
run_hook a3
check "one cap over the whole set, not one per file" \
    "$(printf '%s' "$RUN_TEXT" | grep -c '^- ' | tr -d ' ')" "6"
check "the overflow line does not claim one file" \
    "$(printf '%s' "$RUN_TEXT" | grep -c 'more findings in this file' | tr -d ' ')" "0"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
