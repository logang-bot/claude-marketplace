#!/bin/sh
# Fixtures for the SubagentStart rule injection.
#
# The hook's output is JSON on stdout rather than an exit code, so what matters is that it
# parses, carries the right event name, and actually contains the rules. It is checked
# structurally with grep rather than with a JSON parser: these suites run on Windows Git
# Bash, where no interpreter beyond awk and the POSIX utilities is guaranteed.
#
# Escaping is exercised through jsonout.awk directly. Driving it through the hook would only
# ever test the text that happens to be in the SKILL.md files today, and the character that
# breaks a payload is the one nobody wrote yet.
#
# Run: sh plugins/general-code-style/tests/test_inject_rules.sh

set -u
HERE=$(dirname "$0")
HOOK=$HERE/../hooks/inject-rules.sh
LIB=$HERE/../hooks/lib
FAILURES=0

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

PAYLOAD='{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"general-purpose"}'
OUT=$(printf '%s' "$PAYLOAD" | sh "$HOOK" 2>/dev/null)

# --- the envelope ------------------------------------------------------------

check "a valid payload exits 0" \
    "$(printf '%s' "$PAYLOAD" | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "the output is a single line" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "1"
check "it names the event it answers" \
    "$(printf '%s' "$OUT" | grep -c '"hookEventName":"SubagentStart"' | tr -d ' ')" "1"
check "it carries additionalContext" \
    "$(printf '%s' "$OUT" | grep -c '"additionalContext":' | tr -d ' ')" "1"

# --- the rules actually reach the agent --------------------------------------

check "the file rule is included" \
    "$(printf '%s' "$OUT" | grep -c 'Keep files short' | tr -d ' ')" "1"
check "the function rule is included" \
    "$(printf '%s' "$OUT" | grep -c 'Limit the number of parameters' | tr -d ' ')" "1"
check "the comment rule is included" \
    "$(printf '%s' "$OUT" | grep -c 'Never explain code with inline comments' | tr -d ' ')" "1"
check "shell-written code is named as in scope" \
    "$(printf '%s' "$OUT" | grep -c 'generator script' | tr -d ' ')" "1"

# Frontmatter is activation metadata for the client, not instruction for the agent.
check "frontmatter is stripped" \
    "$(printf '%s' "$OUT" | grep -c 'description:' | tr -d ' ')" "0"

# The client caps additionalContext at 8000 characters and drops what is over.
check "the payload stays under the cap" \
    "$(printf '%s' "$OUT" | wc -c | tr -d ' ' | awk '{ print ($1 < 8000) ? "under" : "over" }')" \
    "under"

# --- bad input is silent, never noisy ----------------------------------------

check "an empty payload is silent" "$(printf '' | sh "$HOOK" 2>/dev/null | wc -c | tr -d ' ')" "0"
check "an empty payload still exits 0" \
    "$(printf '' | sh "$HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"

# --- escaping, where a payload actually breaks -------------------------------

escaped=$(printf 'a"b\\c\td' | awk -f "$LIB/jsonout.awk" -v event=SubagentStart)
check "a quote is escaped" "$(printf '%s' "$escaped" | grep -c 'a\\"b' | tr -d ' ')" "1"
check "a backslash is escaped" "$(printf '%s' "$escaped" | grep -c 'b\\\\c' | tr -d ' ')" "1"
check "a tab is escaped" "$(printf '%s' "$escaped" | grep -c 'c\\td' | tr -d ' ')" "1"
check "a newline never reaches the output raw" \
    "$(printf 'one\ntwo' | awk -f "$LIB/jsonout.awk" -v event=SubagentStart | wc -l | tr -d ' ')" "1"

# Truncating escaped output could sever a \uXXXX; the limit applies to the raw text.
check "the limit truncates" \
    "$(printf 'abcdefghij' | awk -f "$LIB/jsonout.awk" -v event=SubagentStart -v limit=4 \
       | grep -c '"additionalContext":"abcd"' | tr -d ' ')" "1"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
