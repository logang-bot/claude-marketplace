#!/bin/sh
# Fixtures for the batch size check.
#
# The point of moving this hook to PostToolBatch is that a batch is measured once rather than per
# tool call, so the cases that matter are the ones a per-call hook could not get right: the cap
# applying across the whole batch, and a tool that did not write being kept out of it.
#
# That second one is the sharp edge. No matcher is set in hooks.json, because a PostToolBatch
# matcher has to match every call in the batch — one Read beside a Write would skip the hook
# entirely. So the write-tool filter is the script's job, and a regression there would quietly
# start measuring files that were only read.
#
# The rest of these fixtures are about the two things that changed in 0.11.0: the hook answers on
# stdout with non-error feedback rather than exiting 2, and it reports only what the request
# introduced. A file the request inherited says nothing however many times it is written to.
#
# Run: sh plugins/general-code-style/tests/test_batch_scan.sh

set -u
HERE=$(dirname "$0")
HOOK=$HERE/../hooks/check-size.sh
PROMPT_HOOK=$HERE/../hooks/snapshot-turn.sh
LIB=$HERE/../hooks/lib
WORK=${TMPDIR:-/tmp}/batch-scan-test.$$
FAILURES=0

TMPDIR=$WORK/state
export TMPDIR

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/repo" "$WORK/state"
git -C "$WORK/repo" init -q .

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

# Every run of the hook records what it reported, so a scenario has to be run once and asserted
# against afterwards — calling it twice is itself one of the behaviours under test.
run_hook() {
    RUN_OUT=$(printf '%s' "$1" | sh "$HOOK" 2>/dev/null)
    RUN_STATUS=$?
}

# The answer read back with the plugin's own parser, which also asserts that what the hook emits
# is JSON the client could actually parse.
context_of() {
    printf '%s' "$1" | awk -f "$LIB/json.awk" -v key=hookSpecificOutput.additionalContext
}

advisory_for() {
    run_hook "$1"
    context_of "$RUN_OUT"
}

begin_request() {
    printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt_id":"%s","cwd":"%s","prompt":"go"}' \
        "$1" "$WORK/repo" | sh "$PROMPT_HOOK" >/dev/null 2>&1
}

# `_i` rather than `n`, because these are called from loops that count with `n` of their own and
# a shell function shares its caller's variables.
oversized() {
    printf 'package a.b\n\n'
    _i=0
    while [ "$_i" -lt 300 ]; do
        printf 'val line%s = %s\n' "$_i" "$_i"
        _i=$((_i + 1))
    done
}

long_function() {
    printf 'package a.b\n\nfun %s(a: Int) {\n' "$1"
    _i=0
    while [ "$_i" -lt 14 ]; do
        printf '    val v%s = %s\n' "$_i" "$_i"
        _i=$((_i + 1))
    done
    printf '}\n'
}

call() {
    printf '{"tool_name":"%s","tool_input":{"file_path":"%s/repo/%s"},"tool_use_id":"t%s"}' \
        "$1" "$WORK" "$2" "$3"
}

batch_of() {
    printf '{"hook_event_name":"PostToolBatch","session_id":"s1","prompt_id":"p1","cwd":"%s","tool_calls":[%s]}' \
        "$WORK/repo" "$1"
}

# The snapshot is taken before anything is written, so everything below is this request's work.
begin_request p1
oversized > "$WORK/repo/One.kt"
long_function helperOne > "$WORK/repo/Two.kt"
oversized > "$WORK/repo/JustRead.kt"

# --- a batch is measured as one thing ----------------------------------------

batch=$(batch_of "$(call Write One.kt 1),$(call Read JustRead.kt 2),$(call Edit Two.kt 3)")

run_hook "$batch"
advisory=$(context_of "$RUN_OUT")

check "a batch with a finding answers" "$RUN_STATUS" "0"
check "and answers on stdout, not as an error" \
    "$(printf '%s' "$RUN_OUT" | grep -c 'additionalContext' | tr -d ' ')" "1"
check "the written file is named" \
    "$(printf '%s' "$advisory" | grep -c 'One.kt' | tr -d ' ')" "1"
check "the edited file is named too" \
    "$(printf '%s' "$advisory" | grep -c 'Two.kt' | tr -d ' ')" "1"

# The filter that a hooks.json matcher cannot do. Without it, reading a long file warns.
check "a file that was only read is not measured" \
    "$(printf '%s' "$advisory" | grep -c 'JustRead.kt' | tr -d ' ')" "0"

read_only=$(batch_of "$(call Read JustRead.kt 1)")
run_hook "$read_only"
check "a batch that wrote nothing is silent" "$RUN_STATUS" "0"
check "and says nothing" "$RUN_OUT" ""

# --- the two findings are routed differently ---------------------------------

begin_request p2
long_function helperTwo > "$WORK/repo/Local.kt"
local_batch=$(batch_of "$(call Write Local.kt 1)")
advisory=$(advisory_for "$local_batch")

check "a function over the cap is ordered, here and now" \
    "$(printf '%s' "$advisory" | grep -c 'Fix them now' | tr -d ' ')" "1"

begin_request p3
oversized > "$WORK/repo/Big.kt"
size_batch=$(batch_of "$(call Write Big.kt 1)")
advisory=$(advisory_for "$size_batch")

check "file size is handed to the user, not ordered" \
    "$(printf '%s' "$advisory" | grep -c 'for the user rather than for you' | tr -d ' ')" "1"
check "and explicitly says not to split it now" \
    "$(printf '%s' "$advisory" | grep -c 'Do not split it now' | tr -d ' ')" "1"
check "so it never carries the old order to split" \
    "$(printf '%s' "$advisory" | grep -c 'Split it into' | tr -d ' ')" "0"

# The repro from the report that started this: the same file written three times in one request
# produced three identical orders.
check "writing the same file again says nothing the second time" \
    "$(advisory_for "$size_batch")" ""
check "nor the third" "$(advisory_for "$size_batch")" ""

# --- inherited findings are not this request's to answer for -----------------

begin_request p4
printf 'val afterwards = 1\n' >> "$WORK/repo/Big.kt"
inherited=$(batch_of "$(call Edit Big.kt 1)")
check "touching a file that was already over the cap says nothing" \
    "$(advisory_for "$inherited")" ""

# --- the cap applies once over the batch, not once per call ------------------

begin_request p5
n=1
calls=""
while [ "$n" -le 8 ]; do
    long_function "helper$n" > "$WORK/repo/Many$n.kt"
    [ -n "$calls" ] && calls="$calls,"
    calls="$calls$(call Write "Many$n.kt" "$n")"
    n=$((n + 1))
done
check "one cap over the batch, not one per call" \
    "$(advisory_for "$(batch_of "$calls")" | grep -c '^- ' | tr -d ' ')" "6"

# --- payload shapes ----------------------------------------------------------

begin_request p6
long_function single > "$WORK/repo/Single.kt"
one_call="{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"s1\",\"prompt_id\":\"p6\",\"cwd\":\"$WORK/repo\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORK/repo/Single.kt\"}}"
check "a single-call payload still works" \
    "$(advisory_for "$one_call" | grep -c 'Single.kt' | tr -d ' ')" "1"

begin_request p7
long_function booked > "$WORK/repo/Book.kt"
notebook="{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"s1\",\"prompt_id\":\"p7\",\"cwd\":\"$WORK/repo\",\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"$WORK/repo/Book.kt\"}}"
check "a notebook path spelling still works" \
    "$(advisory_for "$notebook" | grep -c 'Book.kt' | tr -d ' ')" "1"

check "a malformed payload is silent" \
    "$(printf 'not json' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
run_hook '{"hook_event_name":"PostToolBatch","tool_calls":[]}'
check "a payload naming no file is silent" "$RUN_STATUS" "0"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
