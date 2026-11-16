#!/bin/sh
# Fixtures for snapshot-turn.sh and check-turn.sh, the request baseline and the Stop backstop.
#
# The Stop hook must lint what the request changed however it was written, ignore what was dirty
# before the request began, give the /design-audit pointer once per request, and fall silent when
# it has nothing new — or the conversation it keeps alive would never end.
#
# Run: sh plugins/web-design/tests/test_turn.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOKS=$HERE/../hooks
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-turn.$$
mkdir -p "$WORK/tmp" "$WORK/repo" "$WORK/nogit"
trap 'rm -rf "$WORK"' EXIT INT TERM
export TMPDIR="$WORK/tmp"
R=$WORK/repo

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

has() { printf '%s' "$1" | grep -c -- "$2" | tr -d ' '; }

G=$(printf 'g%s' 'it')
$G -C "$R" init -q
printf '<p>Hello</p>\n' > "$R/index.html"
$G -C "$R" add index.html
$G -C "$R" -c user.email=t@example.com -c user.name=t commit -q -m init

# Dirty before the request: must never be reported.
printf 'p { text-align: justify; }\n' > "$R/old.css"

prompt() {
    printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt_id":"%s","cwd":"%s","prompt":"%s"}' \
        "$1" "$R" "$2" | sh "$HOOKS/snapshot-turn.sh" 2>/dev/null
}
stop() {
    printf '{"hook_event_name":"Stop","session_id":"s1","cwd":"%s","stop_hook_active":%s}' "$R" "${1:-false}" \
        | sh "$HOOKS/check-turn.sh" 2>/dev/null
}

prompt q1 "Build the landing page"
check "the snapshot is taken" "$(ls "$TMPDIR/web-design" | grep -c 's1.snapshot' | tr -d ' ')" "1"
check "nothing changed yet means silence" "$(stop)" ""

# A shell write: no tool payload names it, only git sees it.
printf '<p style="font-weight: 300">Hi</p>\n' > "$R/index.html"
OUT=$(stop)
check "a shell-written finding is reported" "$(has "$OUT" 'TYPO-08')" "1"
check "the pre-existing dirty file is not" "$(has "$OUT" 'TYPO-13')" "0"
check "the /design-audit pointer is given" "$(has "$OUT" '/design-audit')" "1"
check "the event is named" "$(has "$OUT" '"hookEventName":"Stop"')" "1"
check "the next yield is silent" "$(stop)" ""

printf '<p style="font-weight: 300">Hi</p>\n<i class="bi bi-star"></i>\n' > "$R/index.html"
printf 'import { X } from "lucide-react";\nexport const A = () => <X />;\n' > "$R/App.jsx"
OUT=$(stop)
check "a new cross-file finding is reported" "$(has "$OUT" 'ICON-02')" "1"
check "an old finding is not repeated" "$(has "$OUT" 'TYPO-08')" "0"
check "the pointer is not repeated" "$(has "$OUT" '/design-audit')" "0"

check "stop_hook_active stands down" "$(printf 'a { transition: all 9s; }\n' > "$R/x.css"; stop true)" ""

# A background task's wake is not a new request: the baseline and the told set are kept.
prompt q1b "<task-notification>done</task-notification>"
OUT=$(stop)
check "a wake keeps the request" "$(has "$OUT" 'TYPO-08')" "0"
check "but new work is still seen" "$(has "$OUT" 'UX-04')" "1"

# A new human prompt starts a new request: new baseline, so earlier work is no longer its own.
prompt q2 "Now add a footer"
check "a new request starts silent" "$(stop)" ""
printf 'a { transition: all 9s; }\n.f { color: #000; }\n' > "$R/x.css"
OUT=$(stop)
check "the new request's own change is reported" "$(has "$OUT" 'COLOR-10')" "1"
check "the pointer comes back for the new request" "$(has "$OUT" '/design-audit')" "1"

# --- degraded environments ---------------------------------------------------

OUT=$(printf '{"hook_event_name":"Stop","session_id":"s2","cwd":"%s"}' "$WORK/nogit" | sh "$HOOKS/check-turn.sh" 2>/dev/null)
check "outside git it is silent" "$OUT" ""
OUT=$(printf '{"hook_event_name":"Stop","session_id":"s3","cwd":"%s"}' "$R" | sh "$HOOKS/check-turn.sh" 2>/dev/null)
check "without a snapshot it takes one and claims nothing" "$OUT" ""
check "an empty payload is silent" "$(printf '' | sh "$HOOKS/check-turn.sh" 2>/dev/null)" ""

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
