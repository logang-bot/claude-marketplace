#!/bin/sh
# Fixtures for check-batch.sh, the PostToolBatch lint.
#
# The behaviour worth pinning is scope: a Write owns the whole file, an Edit owns only the lines
# its new_string wrote, a finding is told once per request, and a batch that wrote nothing web
# says nothing at all.
#
# Run: sh plugins/web-design/tests/test_batch.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOK=$HERE/../hooks/check-batch.sh
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-batch.$$
mkdir -p "$WORK/tmp" "$WORK/p"
trap 'rm -rf "$WORK"' EXIT INT TERM
export TMPDIR="$WORK/tmp"
P=$WORK/p

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

has() { printf '%s' "$1" | grep -c -- "$2" | tr -d ' '; }

# batch <session> <calls-json>
batch() {
    printf '{"hook_event_name":"PostToolBatch","session_id":"%s","prompt_id":"q1","cwd":"%s","tool_calls":[%s]}' \
        "$1" "$P" "$2" | sh "$HOOK" 2>/dev/null
}

# --- an Edit owns only its own lines -----------------------------------------

printf '.a { text-align: justify; }\n.b { font-weight: 300; }\n' > "$P/style.css"
EDIT='{"tool_name":"Edit","tool_input":{"file_path":"'$P'/style.css","old_string":"x","new_string":".b { font-weight: 300; }"}}'
OUT=$(batch e1 "$EDIT")
check "the edit's own finding is reported" "$(has "$OUT" 'TYPO-08')" "1"
check "an inherited finding is not" "$(has "$OUT" 'TYPO-13')" "0"
check "the event is named" "$(has "$OUT" '"hookEventName":"PostToolBatch"')" "1"
check "paths are shown relative to the project" "$(has "$OUT" 'style.css:2')" "1"
check "the same finding is not told twice" "$(batch e1 "$EDIT")" ""

# --- a Write owns the whole file ---------------------------------------------

WRITE='{"tool_name":"Write","tool_input":{"file_path":"'$P'/style.css","content":"..."}}'
OUT=$(batch e2 "$WRITE")
check "a Write reports the justify" "$(has "$OUT" 'TYPO-13')" "1"
check "a Write reports the weight" "$(has "$OUT" 'TYPO-08')" "1"

# --- MultiEdit, multi-line new_string ----------------------------------------

printf '.c { color: #333; }\n.d {\n  transition: all 2s;\n}\n' > "$P/two.css"
MULTI='{"tool_name":"MultiEdit","tool_input":{"file_path":"'$P'/two.css","edits":[{"old_string":"x","new_string":".d {\n  transition: all 2s;\n}"}]}}'
OUT=$(batch e3 "$MULTI")
check "a line inside a multi-line new_string is reported" "$(has "$OUT" 'UX-04')" "1"

# --- batches that wrote nothing web ------------------------------------------

READ='{"tool_name":"Read","tool_input":{"file_path":"'$P'/style.css"}}'
check "a Read-only batch is silent" "$(batch e4 "$READ")" ""
printf 'x = 1\n' > "$P/a.py"
PY='{"tool_name":"Write","tool_input":{"file_path":"'$P'/a.py","content":"x"}}'
check "a non-web write is silent" "$(batch e4 "$PY")" ""
OUT=$(batch e5 "$READ,$WRITE")
check "a Read beside a Write still lints the Write" "$(has "$OUT" 'TYPO-08')" "1"

printf '.ok { color: #333; padding: 16px; }\n' > "$P/clean.css"
CLEAN='{"tool_name":"Write","tool_input":{"file_path":"'$P'/clean.css","content":"x"}}'
check "a clean file is silent" "$(batch e6 "$CLEAN")" ""

# --- the single-call shape (PostToolUse) -------------------------------------

OUT=$(printf '{"hook_event_name":"PostToolUse","session_id":"e7","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s/style.css","new_string":".b { font-weight: 300; }"}}' \
    "$P" "$P" | sh "$HOOK" 2>/dev/null)
check "the single-call shape works" "$(has "$OUT" 'TYPO-08')" "1"
check "and keeps the Edit scope" "$(has "$OUT" 'TYPO-13')" "0"

check "an empty payload is silent" "$(printf '' | sh "$HOOK" 2>/dev/null)" ""

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
