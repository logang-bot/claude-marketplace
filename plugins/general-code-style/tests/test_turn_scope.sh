#!/bin/sh
# Fixtures for turn scoping.
#
# The hook used to report every untracked file on every turn, because untracked never expires,
# and to exclude modifications entirely. Both halves were wrong: it ordered fixes on files the
# agent had never touched, and stayed silent on files it had just changed.
#
# So the cases that matter are the transitions, not any single run. A file must be reported on
# the turn it was worked on and silent on the next one, and the sequence below walks a file
# through create, idle, rename, idle, modify and fix in that order.
#
# The rename case is the one that prompted all of this: `mv` preserves mtime, so a check built
# on timestamps would miss exactly the file the user was complaining about. It is caught here
# because the path is new to the snapshot, not because anything about its contents changed.
#
# Run: sh plugins/general-code-style/tests/test_turn_scope.sh

set -u
HERE=$(dirname "$0")
PROMPT_HOOK=$HERE/../hooks/snapshot-turn.sh
STOP_HOOK=$HERE/../hooks/check-new-files.sh
WORK=${TMPDIR:-/tmp}/turn-scope-test.$$
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

payload() {
    printf '{"session_id":"%s","cwd":"%s","prompt_id":"%s"}' "${SID:-s1}" "$WORK/repo" "$1"
}

begin_turn() { payload "$1" | sh "$PROMPT_HOOK" >/dev/null 2>&1; }
end_turn()   { payload "$1" | sh "$STOP_HOOK" >/dev/null 2>&1; printf '%s' "$?"; }
end_turn_text() { payload "$1" | sh "$STOP_HOOK" 2>&1 >/dev/null; }

oversized() {
    printf 'using System;\n\n'
    n=0
    while [ "$n" -lt 289 ]; do
        printf 'int v%s = %s;\n' "$n" "$n"
        n=$((n + 1))
    done
}

git -C "$WORK/repo" init -q .

# --- the sequence ------------------------------------------------------------

# Turn one is the case a snapshot written at Stop could never cover: there would be no baseline
# to compare against, and turn one is usually the turn that creates the files.
begin_turn t1
oversized > "$WORK/repo/src/Boss.cs"
check "a file created on the very first turn is caught" "$(end_turn t1)" "2"

begin_turn t2
check "the same file, untouched, is silent next turn" "$(end_turn t2)" "0"

# `mv` keeps mtime, so this is the case a timestamp check would miss.
begin_turn t3
mv "$WORK/repo/src/Boss.cs" "$WORK/repo/src/MarauderBoss.cs"
check "a plain rename is caught on the turn it happens" "$(end_turn t3)" "2"
check "the renamed path is the one named" \
    "$(end_turn_text t3 | grep -c 'MarauderBoss.cs' | tr -d ' ')" "2"

begin_turn t4
check "the renamed file is silent the turn after" "$(end_turn t4)" "0"

# Modifications were excluded outright by the old --diff-filter=A, so this never reported.
begin_turn t5
printf 'int extra = 1;\n' >> "$WORK/repo/src/MarauderBoss.cs"
check "modifying an existing file is caught" "$(end_turn t5)" "2"

begin_turn t6
printf 'using System;\n\nclass Small { }\n' > "$WORK/repo/src/MarauderBoss.cs"
check "bringing it under the cap ends the reports" "$(end_turn t6)" "0"

# --- the wording has to actually order the fix -------------------------------

begin_turn t7
oversized > "$WORK/repo/src/Another.cs"
advisory=$(end_turn_text t7)

check "it states a required fix, not an advisory" \
    "$(printf '%s' "$advisory" | grep -c 'required fix' | tr -d ' ')" "1"
# The excuse this change exists to remove: the agent declined because the file was already
# that shape before it renamed it.
check "the pre-existing-shape excuse is refused" \
    "$(printf '%s' "$advisory" | grep -c 'is not a reason to skip it' | tr -d ' ')" "1"
# And the counterweight: an order to fix must not become a licence to refactor the project.
check "the order is scoped to these files" \
    "$(printf '%s' "$advisory" | grep -c 'Only these files' | tr -d ' ')" "1"

# --- guards ------------------------------------------------------------------

check "a second stop in the same turn is silent" \
    "$(payload t7 | sed 's/}$/,"stop_hook_active":true}/' | sh "$STOP_HOOK" >/dev/null 2>&1; printf '%s' "$?")" \
    "0"

# A session that never ran the prompt hook has no baseline. Recording one and staying quiet is
# the only honest option; claiming the whole dirty tree would be the false order this design
# exists to stop.
SID=fresh
check "a session with no snapshot records instead of reporting" "$(end_turn u1)" "0"
check "and reports normally once it has one" \
    "$(begin_turn u2; oversized > "$WORK/repo/src/Later.cs"; end_turn u2)" "2"
SID=s1

check "a malformed payload is silent" \
    "$(printf 'not json' | sh "$STOP_HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"
check "outside a repository is silent" \
    "$(printf '{"cwd":"/usr"}' | sh "$STOP_HOOK" >/dev/null 2>&1; printf '%s' "$?")" "0"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
