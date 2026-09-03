#!/bin/sh
# Fixtures for the batch size check.
#
# The point of moving this hook to PostToolBatch is that a batch is measured once rather
# than per tool call, so the cases that matter are the ones a per-call hook could not get
# right: the cap applying across the whole batch, and a tool that did not write being kept
# out of it.
#
# That second one is the sharp edge. No matcher is set in hooks.json, because a
# PostToolBatch matcher has to match every call in the batch — one Read beside a Write would
# skip the hook entirely. So the write-tool filter is the script's job, and a regression
# there would quietly start measuring files that were only read.
#
# Run: sh plugins/general-code-style/tests/test_batch_scan.sh

set -u
HERE=$(dirname "$0")
HOOK=$HERE/../hooks/check-size.sh
LIB=$HERE/../hooks/lib
WORK=${TMPDIR:-/tmp}/batch-scan-test.$$
FAILURES=0

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

advisory_for() {
    printf '%s' "$1" | sh "$HOOK" 2>&1 >/dev/null
}

status_for() {
    printf '%s' "$1" | sh "$HOOK" >/dev/null 2>&1
    printf '%s' "$?"
}

oversized() {
    printf 'package a.b\n\n'
    n=0
    while [ "$n" -lt 300 ]; do
        printf 'val line%s = %s\n' "$n" "$n"
        n=$((n + 1))
    done
}

call() {
    printf '{"tool_name":"%s","tool_input":{"file_path":"%s/%s"},"tool_use_id":"t%s"}' \
        "$1" "$WORK" "$2" "$3"
}

oversized > "$WORK/One.kt"
oversized > "$WORK/Two.kt"
oversized > "$WORK/JustRead.kt"

# --- a batch is measured as one thing ----------------------------------------

batch="{\"hook_event_name\":\"PostToolBatch\",\"tool_calls\":[$(call Write One.kt 1),\
$(call Read JustRead.kt 2),$(call Edit Two.kt 3)]}"

check "a batch with a violation advises" "$(status_for "$batch")" "2"
check "the written file is named" \
    "$(advisory_for "$batch" | grep -c 'One.kt' | tr -d ' ')" "1"
check "the edited file is named too" \
    "$(advisory_for "$batch" | grep -c 'Two.kt' | tr -d ' ')" "1"

# The filter that a hooks.json matcher cannot do. Without it, reading a long file warns.
check "a file that was only read is not measured" \
    "$(advisory_for "$batch" | grep -c 'JustRead.kt' | tr -d ' ')" "0"

read_only="{\"hook_event_name\":\"PostToolBatch\",\"tool_calls\":[$(call Read JustRead.kt 1)]}"
check "a batch that wrote nothing is silent" "$(status_for "$read_only")" "0"

# --- the cap applies once, over the batch ------------------------------------

n=0
calls=""
while [ "$n" -lt 8 ]; do
    printf 'package a.b\n\nfun f%s(a: Int, b: Int, c: Int, d: Int) {\n    val x = a\n}\n' \
        "$n" > "$WORK/Wide$n.kt"
    [ -n "$calls" ] && calls="$calls,"
    calls="$calls$(call Write "Wide$n.kt" "$n")"
    n=$((n + 1))
done
wide_batch="{\"hook_event_name\":\"PostToolBatch\",\"tool_calls\":[$calls]}"

check "one cap over the batch, not one per call" \
    "$(advisory_for "$wide_batch" | grep -c '^- ')" "6"
check "the overflow line does not claim one file" \
    "$(advisory_for "$wide_batch" | grep -c 'more findings in this file' | tr -d ' ')" "0"

single="{\"hook_event_name\":\"PostToolBatch\",\"tool_calls\":[$(call Write One.kt 1)]}"
check "a one-call batch may name the file" \
    "$(advisory_for "$single" | grep -c 'JustRead' | tr -d ' ')" "0"

# --- the fallback that survives PostToolBatch being inert --------------------

check "a single-call payload still works" \
    "$(status_for "{\"tool_input\":{\"file_path\":\"$WORK/One.kt\"}}")" "2"
check "a notebook path spelling still works" \
    "$(status_for "{\"tool_input\":{\"notebook_path\":\"$WORK/One.kt\"}}")" "2"

# --- the wording orders the fix ----------------------------------------------

check "it states a required fix, not an advisory" \
    "$(advisory_for "$batch" | grep -c 'required fix' | tr -d ' ')" "1"
check "the pre-existing-shape excuse is refused" \
    "$(advisory_for "$batch" | grep -c 'is not a reason to skip it' | tr -d ' ')" "1"
check "the order is scoped to the files it names" \
    "$(advisory_for "$batch" | grep -c 'Only these files' | tr -d ' ')" "1"

# --- bad input is silent -----------------------------------------------------

check "a malformed payload is silent" "$(status_for 'not json')" "0"
check "an empty payload is silent" "$(status_for '')" "0"
check "a missing file is silent" \
    "$(status_for "{\"tool_input\":{\"file_path\":\"$WORK/Absent.kt\"}}")" "0"

# --- the index pairing the filter rests on -----------------------------------

names=$(printf '%s' "$batch" | awk -f "$LIB/json.awk" -v key='tool_calls[].tool_name' -v all=1 \
    | tr '\n' ' ' | sed 's/ $//')
check "array matches carry their index" "$names" "1	Write 2	Read 3	Edit"

check "a key absent from the array exits 1" \
    "$(printf '%s' "$batch" | awk -f "$LIB/json.awk" -v key='tool_calls[].nope' -v all=1 \
       >/dev/null 2>&1; printf '%s' "$?")" "1"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
