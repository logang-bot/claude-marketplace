#!/bin/sh
# Fixtures for the plan-time rule injection.
#
# Three triggers and two payloads, so the suite has to assert which one arrived as well as
# that something did. It is checked structurally with grep rather than with a JSON parser:
# these suites run on Windows Git Bash, where no interpreter beyond awk and the POSIX
# utilities is guaranteed. Escaping is already covered against jsonout.awk directly by
# test_inject_rules.sh and is not repeated here.
#
# TMPDIR is redirected to a scratch directory, because the episode marker is real on-disk
# state and a suite that wrote to the developer's own TMPDIR would suppress the injection in
# their next session.
#
# Run: sh plugins/general-code-style/tests/test_plan_rules.sh

set -u
HERE=$(dirname "$0")
HOOK=$HERE/../hooks/inject-plan-rules.sh
LIB=$HERE/../hooks/lib
FAILURES=0

WORK=${TMPDIR:-/tmp}/plan-rules-test.$$
mkdir -p "$WORK/state" || exit 1
TMPDIR=$WORK/state
export TMPDIR
trap 'rm -rf "$WORK"' EXIT INT TERM

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

prompt_payload() {
    printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s","permission_mode":"%s","prompt":"do a thing"}' "$1" "$2"
}

tool_payload() {
    printf '{"hook_event_name":"PreToolUse","session_id":"%s","tool_name":"%s","tool_input":{"skill":"%s"}}' "$1" "$2" "$3"
}

run() { printf '%s' "$1" | sh "$HOOK" 2>/dev/null; }
bytes() { printf '%s' "$1" | wc -c | tr -d ' '; }
grep_count() { printf '%s' "$2" | grep -c "$1" | tr -d ' '; }

# --- a plan-mode prompt is served the budgets ---------------------------------

OUT=$(run "$(prompt_payload plan-a plan)")

check "a plan-mode prompt exits 0" \
    "$(printf '%s' "$(prompt_payload plan-b plan)" | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "the output is a single line" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "1"
check "it names the event it answers" \
    "$(grep_count '"hookEventName":"UserPromptSubmit"' "$OUT")" "1"

# The numbers must come from limits.awk, not from a second copy in the digest.
check "the file cap is the live one" "$(grep_count '250 lines' "$OUT")" "1"
check "the body cap is the live one" "$(grep_count '10 lines' "$OUT")" "1"
check "planning a split is asked for" "$(grep_count 'plan the split now' "$OUT")" "1"
check "the UI exemption is carried" "$(grep_count 'exempt from the body and parameter caps' "$OUT")" "1"

# A digest that cost as much as the rules it summarises would have no reason to exist.
check "the digest is smaller than the full rules" \
    "$(awk -v d="$(bytes "$OUT")" -v r="$(bytes "$(run "$(tool_payload sizing ExitPlanMode '')")")" \
       'BEGIN { print (d < r) ? "smaller" : "not smaller" }')" "smaller"

# --- and served them once, not once per turn ----------------------------------

check "a second plan prompt in the same session is silent" \
    "$(bytes "$(run "$(prompt_payload plan-a plan)")")" "0"
check "a different session is served in its own right" \
    "$(grep_count 'design budgets' "$(run "$(prompt_payload plan-c plan)")")" "1"

# --- a prompt outside plan mode is not served ---------------------------------

check "a default-mode prompt is silent" "$(bytes "$(run "$(prompt_payload other default)")")" "0"
check "an acceptEdits prompt is silent" "$(bytes "$(run "$(prompt_payload other2 acceptEdits)")")" "0"
check "a prompt with no permission_mode is silent" \
    "$(bytes "$(run '{"hook_event_name":"UserPromptSubmit","session_id":"nomode","prompt":"go"}')")" "0"

# --- the handoff into implementation gets the rules themselves ----------------

HANDOFF=$(run "$(tool_payload hand-a ExitPlanMode '')")

check "ExitPlanMode names PreToolUse in the envelope" \
    "$(grep_count '"hookEventName":"PreToolUse"' "$HANDOFF")" "1"
check "the file rule is included" "$(grep_count 'Keep files short' "$HANDOFF")" "1"
check "the parameter rule is included" "$(grep_count 'Limit the number of parameters' "$HANDOFF")" "1"
check "the comment rule is included" "$(grep_count 'Never explain code with inline comments' "$HANDOFF")" "1"
check "shell-written code is named as in scope" "$(grep_count 'generator script' "$HANDOFF")" "1"
check "the approved plan is refused as an excuse" \
    "$(grep_count 'does not exempt the code it produces' "$HANDOFF")" "1"
check "frontmatter is stripped" "$(grep_count 'description:' "$HANDOFF")" "0"

# The episode ends at the handoff, so the next round of planning is served again.
run "$(tool_payload plan-a ExitPlanMode '')" >/dev/null
check "planning after a handoff is served again" \
    "$(grep_count 'design budgets' "$(run "$(prompt_payload plan-a plan)")")" "1"

# --- the brainstorming trigger ------------------------------------------------

check "a brainstorming skill is served the budgets" \
    "$(grep_count 'design budgets' "$(run "$(tool_payload bs-a Skill 'superpowers:brainstorming')")")" "1"
check "the match ignores case" \
    "$(grep_count 'design budgets' "$(run "$(tool_payload bs-b Skill 'Superpowers:Brainstorming')")")" "1"
check "an unrelated skill is silent" \
    "$(bytes "$(run "$(tool_payload bs-c Skill 'dev-workflow:changelog')")")" "0"
check "a Skill call with no skill named is silent" \
    "$(bytes "$(run '{"hook_event_name":"PreToolUse","session_id":"bs-d","tool_name":"Skill","tool_input":{}}')")" "0"
check "an unrelated tool is silent" \
    "$(bytes "$(run "$(tool_payload bs-e Write '')")")" "0"

# --- bad input is silent, never noisy -----------------------------------------

check "an empty payload is silent" "$(bytes "$(printf '' | sh "$HOOK" 2>/dev/null)")" "0"
check "an empty payload still exits 0" \
    "$(printf '' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "malformed JSON is silent" "$(bytes "$(run '{"hook_event_name":')")" "0"
check "malformed JSON still exits 0" \
    "$(printf '%s' '{"hook_event_name":' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "an unhandled event is silent" \
    "$(bytes "$(run '{"hook_event_name":"Stop","session_id":"s"}')")" "0"

# Exit 2 would block the user's prompt on one event and the tool call on the other.
check "the handoff exits 0, never 2" \
    "$(printf '%s' "$(tool_payload hand-z ExitPlanMode '')" | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"

# --- the client's cap ---------------------------------------------------------

check "the digest stays under the cap" \
    "$(awk -v n="$(bytes "$OUT")" 'BEGIN { print (n < 8000) ? "under" : "over" }')" "under"
check "the full rules stay under the cap" \
    "$(awk -v n="$(bytes "$HANDOFF")" 'BEGIN { print (n < 8000) ? "under" : "over" }')" "under"

# --- state it cannot keep must not become silence -----------------------------
#
# check-new-files.sh exits 1 when it cannot keep state, because reporting without a baseline
# means issuing false orders. Here the worst a missing marker does is repeat a digest, so the
# hook injects anyway; falling silent would mean the rules never arrive at all.

UNWRITABLE=$WORK/readonly
mkdir -p "$UNWRITABLE" && chmod 500 "$UNWRITABLE"
check "an unwritable TMPDIR still injects" \
    "$(TMPDIR=$UNWRITABLE grep_count 'design budgets' \
       "$(TMPDIR=$UNWRITABLE run "$(prompt_payload ro-a plan)")")" "1"
chmod 700 "$UNWRITABLE" 2>/dev/null

# --- results ------------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
