#!/bin/sh
# Fixtures for the three injection hooks: inject-rules.sh (SubagentStart), inject-write-rules.sh
# (PreToolUse) and route-prompt.sh (UserPromptSubmit).
#
# What matters is that each answers when it should, stays silent when it should, says it once per
# session, and that the payload fits: the client caps additionalContext at 8000 characters and the
# hooks cut at 7000, so the last rules section arriving intact is the proof nothing was cut.
#
# Run: sh plugins/web-design/tests/test_inject.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOKS=$HERE/../hooks
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-inject.$$
mkdir -p "$WORK/tmp" "$WORK/web" "$WORK/backend" "$WORK/briefed"
trap 'rm -rf "$WORK"' EXIT INT TERM
export TMPDIR="$WORK/tmp"

printf '<p>Hi</p>\n' > "$WORK/web/index.html"
printf 'print(1)\n' > "$WORK/backend/main.py"
printf '# Design brief\n' > "$WORK/briefed/DESIGN.md"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

has() { printf '%s' "$1" | grep -c -- "$2" | tr -d ' '; }
size_ok() { printf '%s' "$1" | wc -c | awk '{ print ($1 < 8000) ? "under" : "over" }'; }

# --- SubagentStart -----------------------------------------------------------

OUT=$(printf '{"hook_event_name":"SubagentStart","cwd":"%s","agent_type":"general-purpose"}' "$WORK/web" \
    | sh "$HOOKS/inject-rules.sh" 2>/dev/null)
check "a web project gets the rules" "$(has "$OUT" '"hookEventName":"SubagentStart"')" "1"
check "the personality section is first in" "$(has "$OUT" 'Personality (PERS)')" "1"
check "the last section survives the cap" "$(has "$OUT" 'Assemble the layout areas into a complete')" "1"
check "frontmatter is stripped" "$(has "$OUT" 'description:')" "0"
check "the skill prose is left out" "$(has "$OUT" 'What the hook checks')" "0"
check "the subagent payload fits" "$(size_ok "$OUT")" "under"
check "it is one line" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "1"

OUT=$(printf '{"hook_event_name":"SubagentStart","cwd":"%s"}' "$WORK/backend" | sh "$HOOKS/inject-rules.sh" 2>/dev/null)
check "a backend project gets nothing" "$OUT" ""
OUT=$(printf '{"hook_event_name":"SubagentStart","cwd":"%s"}' "$WORK/briefed" | sh "$HOOKS/inject-rules.sh" 2>/dev/null)
check "a DESIGN.md alone counts as a web project" "$(has "$OUT" 'additionalContext')" "1"
check "an empty payload is silent" "$(printf '' | sh "$HOOKS/inject-rules.sh" 2>/dev/null)" ""

# --- PreToolUse --------------------------------------------------------------

pre() {
    printf '{"hook_event_name":"PreToolUse","session_id":"%s","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' \
        "$1" "$2" "$3" "$4" | sh "$HOOKS/inject-write-rules.sh" 2>/dev/null
}

OUT=$(pre w1 "$WORK/web" Write "$WORK/web/styles.css")
check "the first stylesheet write gets the rules" "$(has "$OUT" 'Typography (TYPO)')" "1"
check "a new file without DESIGN.md asks the user" "$(has "$OUT" 'let you decide the style')" "1"
check "the nudge leads, so a cut could only trim the tail" \
    "$(printf '%s' "$OUT" | awk '{ print (index($0, "no DESIGN.md") < index($0, "Personality (PERS)")) ? "first" : "last" }')" "first"
check "with the nudge the last section survives" "$(has "$OUT" 'Assemble the layout areas into a complete')" "1"
check "the write payload fits" "$(size_ok "$OUT")" "under"
check "it names the event" "$(has "$OUT" '"hookEventName":"PreToolUse"')" "1"
check "the second write is silent" "$(pre w1 "$WORK/web" Edit "$WORK/web/index.html")" ""
check "a plain .ts write is not a trigger" "$(pre w2 "$WORK/web" Write "$WORK/web/server.ts")" ""
check "a vendored file is not a trigger" "$(pre w2 "$WORK/web" Write "$WORK/web/node_modules/x/a.css")" ""
OUT=$(pre w2 "$WORK/web" Write "$WORK/web/App.tsx")
check "a .tsx write is a trigger" "$(has "$OUT" 'Typography (TYPO)')" "1"
OUT=$(pre w3 "$WORK/briefed" Write "$WORK/briefed/a.css")
check "no nudge when DESIGN.md exists" "$(has "$OUT" 'no DESIGN.md')" "0"
# Editing an existing page first: a one-line mention rides with the digest, no question. The
# first new file afterwards still asks, even though the digest has already been given.
printf 'p { color: #333; }\n' > "$WORK/web/existing.css"
OUT=$(pre w5 "$WORK/web" Edit "$WORK/web/existing.css")
check "an edit without DESIGN.md gets the mention" "$(has "$OUT" 'mention in one line')" "1"
check "an edit is not interrupted by the question" "$(has "$OUT" 'let you decide the style')" "0"
OUT=$(pre w5 "$WORK/web" Write "$WORK/web/new-page.html")
check "the first new file still asks" "$(has "$OUT" 'let you decide the style')" "1"
check "without repeating the digest" "$(has "$OUT" 'Typography (TYPO)')" "0"
check "the question is asked once a session" "$(pre w5 "$WORK/web" Write "$WORK/web/another.html")" ""

check "ExitPlanMode without design intent is silent" "$(pre w4 "$WORK/web" ExitPlanMode "")" ""

# --- UserPromptSubmit --------------------------------------------------------

prompt() {
    printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s","cwd":"%s","permission_mode":"%s","prompt":"%s"}' \
        "$1" "$2" "$3" "$4" | sh "$HOOKS/route-prompt.sh" 2>/dev/null
}

OUT=$(prompt r1 "$WORK/web" default "Build me a landing page for a dentist")
check "a design prompt gets the pointer" "$(has "$OUT" 'choosing-a-website-personality')" "1"
check "it offers /design-brief without DESIGN.md" "$(has "$OUT" '/design-brief')" "1"
check "it asks create-or-decide for new pages" "$(has "$OUT" 'or let you decide the style')" "1"
check "it says to wait for the answer" "$(has "$OUT" 'Wait for the answer')" "1"
check "outside plan mode it carries no digest" "$(has "$OUT" 'Typography (TYPO)')" "0"
check "the pointer is given once" "$(prompt r1 "$WORK/web" default "Now restyle the navbar")" ""
check "a non-design prompt is silent" "$(prompt r2 "$WORK/web" default "Fix the null check in the parser")" ""
OUT=$(prompt r7 "$WORK/web" default "Add a settings screen")
check "a new screen counts as design work" "$(has "$OUT" 'choosing-a-website-personality')" "1"
check "a word containing ui is not ui" "$(prompt r2 "$WORK/web" default "Rebuild the build queue")" ""
check "a task notification is silent" "$(prompt r3 "$WORK/web" default "<task-notification>landing page done</task-notification>")" ""
OUT=$(prompt r4 "$WORK/briefed" default "Change the CSS colours")
check "with a brief it points at DESIGN.md" "$(has "$OUT" 'Read DESIGN.md')" "1"

OUT=$(prompt r5 "$WORK/web" plan "Plan a redesign of the website")
check "plan mode carries the digest" "$(has "$OUT" 'Typography (TYPO)')" "1"
check "in plan mode the last section survives" "$(has "$OUT" 'Assemble the layout areas into a complete')" "1"
check "the plan payload fits" "$(size_ok "$OUT")" "under"
OUT=$(pre r5 "$WORK/web" Write "$WORK/web/a.css")
check "a session served in plan mode is not served the digest again" "$(has "$OUT" 'Typography (TYPO)')" "0"

prompt r6 "$WORK/web" default "Design the pricing page" >/dev/null
OUT=$(pre r6 "$WORK/web" ExitPlanMode "")
check "ExitPlanMode after a design prompt gets the rules" "$(has "$OUT" 'implementation you are about')" "1"

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
