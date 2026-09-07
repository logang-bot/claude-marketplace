#!/bin/sh
# Fixtures for request scoping: whose work a finding belongs to, and when it is said.
#
# The hook used to report every untracked file on every turn, because untracked never expires,
# and to exclude modifications entirely. Both halves were wrong. Worse, it then ordered the fix,
# so one line changed in a file that had been oversized for months produced an order to split it
# — the scope explosion that stalled agents mid-task.
#
# So the cases that matter are transitions, not any single run. A file is reported on the request
# that introduced the finding and silent otherwise, and the sequence below walks one through
# create, idle, rename, idle, modify and fix in that order.
#
# The rename case is the one that prompted the scoping work: `mv` preserves mtime, so a check
# built on timestamps would miss exactly the file the user was complaining about. It is caught
# here because the path is new to the snapshot, not because anything about its contents changed.
#
# Run: sh plugins/general-code-style/tests/test_turn_scope.sh

set -u
HERE=$(dirname "$0")
PROMPT_HOOK=$HERE/../hooks/snapshot-turn.sh
STOP_HOOK=$HERE/../hooks/check-new-files.sh
LIB=$HERE/../hooks/lib
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
    printf '{"session_id":"%s","cwd":"%s","prompt_id":"%s","prompt":"%s"}' \
        "${SID:-s1}" "$WORK/repo" "$1" "${2:-please do the thing}"
}

begin_turn() { payload "$1" "${2:-}" | sh "$PROMPT_HOOK" >/dev/null 2>&1; }

# Runs the hook once and leaves the answer in TEXT. Every run records what it said, so a scenario
# must be run once and asserted against rather than re-run per assertion.
end_turn() {
    OUT=$(payload "$1" | sh "$STOP_HOOK" 2>/dev/null)
    TEXT=$(printf '%s' "$OUT" \
        | awk -f "$LIB/json.awk" -v key=hookSpecificOutput.additionalContext)
}

# "1" when the last answer named the file, "0" when it did not.
named() {
    printf '%s' "$TEXT" | grep -c "$1" | tr -d ' ' | head -c 1
}

oversized() {
    printf 'using System;\n\n'
    _i=0
    while [ "$_i" -lt "${1:-289}" ]; do
        printf 'int v%s = %s;\n' "$_i" "$_i"
        _i=$((_i + 1))
    done
}

git -C "$WORK/repo" init -q .

# --- the sequence ------------------------------------------------------------

# Request one is the case a snapshot written at Stop could never cover: there would be no
# baseline to compare against, and request one is usually the one that creates the files.
begin_turn t1
oversized > "$WORK/repo/src/Boss.cs"
end_turn t1
check "a file created on the very first request is caught" "$(named 'Boss.cs')" "1"

begin_turn t2
end_turn t2
check "the same file, untouched, is silent in a later request" "$OUT" ""

# `mv` keeps mtime, so this is the case a timestamp check would miss.
begin_turn t3
mv "$WORK/repo/src/Boss.cs" "$WORK/repo/src/MarauderBoss.cs"
end_turn t3
check "a plain rename is caught on the request it happens" "$(named 'MarauderBoss.cs')" "1"

begin_turn t4
end_turn t4
check "the renamed file is silent the request after" "$OUT" ""

# This file is over the cap because of this session's own work, so touching it again brings the
# reminder back — that is the "do not let me forget" half of the design. The inherited case, where
# the file was already that shape when the session started, is the section below.
begin_turn t5
printf 'int extra = 1;\n' >> "$WORK/repo/src/MarauderBoss.cs"
end_turn t5
check "touching a file this session made oversized brings the reminder back" \
    "$(named 'MarauderBoss.cs')" "1"
check "and it is a reminder, never an order" \
    "$(printf '%s' "$TEXT" | grep -c 'Fix them' | tr -d ' ')" "0"

# Growing it well past where it already was is a different matter — that shape is this request's.
begin_turn t6
oversized 400 > "$WORK/repo/src/MarauderBoss.cs"
end_turn t6
check "but piling on past the growth allowance is reported" "$(named 'MarauderBoss.cs')" "1"

begin_turn t7
printf 'using System;\n\nclass Small { }\n' > "$WORK/repo/src/MarauderBoss.cs"
end_turn t7
check "bringing it under the cap ends the reports" "$OUT" ""

# --- inherited, as opposed to introduced -------------------------------------

# The scope explosion this rewrite exists to remove: one line changed in a file that was already
# oversized before the session started used to produce an order to split it.
SID=legacy
oversized > "$WORK/repo/src/Legacy.cs"
begin_turn g1
printf 'int extra = 1;\n' >> "$WORK/repo/src/Legacy.cs"
end_turn g1
check "one line added to a file that was already over the cap says nothing" "$OUT" ""

# Even after several requests, an inherited file the session keeps editing stays inherited.
begin_turn g2
printf 'int more = 2;\n' >> "$WORK/repo/src/Legacy.cs"
end_turn g2
check "and it stays silent however often it is touched" "$OUT" ""
SID=s1

# --- crossing the cap, as opposed to inheriting it ---------------------------

begin_turn t8
oversized 100 > "$WORK/repo/src/Grower.cs"
end_turn t8
check "a file created under the cap says nothing" "$OUT" ""

begin_turn t9
oversized 300 > "$WORK/repo/src/Grower.cs"
end_turn t9
check "the request that pushes it over the cap owns it" "$(named 'Grower.cs')" "1"

# --- a request spans several turns -------------------------------------------

# A background subagent finishing wakes the session with a fresh prompt id. Re-snapshotting there
# would fold whatever it wrote into the baseline, and nothing would ever measure it.
SID=wake
begin_turn w1
oversized > "$WORK/repo/src/First.cs"
end_turn w1
check "the introducing request reports it" "$(named 'First.cs')" "1"

snapshot=$WORK/state/general-code-style/wake.snapshot
before=$(cat "$snapshot")
begin_turn w2 "<task-notification>
<task-id>abc</task-id>
</task-notification>"
check "a wake does not retake the snapshot" "$(cat "$snapshot")" "$before"
check "so the request keeps its own id" \
    "$(awk -F'\t' 'NR == 1 { print $2 }' "$snapshot")" "w1"

oversized > "$WORK/repo/src/Second.cs"
end_turn w2
check "a file written after the wake is still measured" "$(named 'Second.cs')" "1"

begin_turn w3 "now do the next thing"
check "a prompt a human typed does retake it" \
    "$(awk -F'\t' 'NR == 1 { print $2 }' "$snapshot")" "w3"
SID=s1

# --- saying it twice ---------------------------------------------------------

# Stop fires at every yield, and the answer no longer blocks, so repeating the same text would
# never terminate. Nothing new to say means saying nothing.
SID=loop
begin_turn l1
oversized > "$WORK/repo/src/Loop.cs"
end_turn l1
check "the first yield says it" "$(named 'Loop.cs')" "1"
end_turn l1
check "a second yield with nothing changed is silent" "$OUT" ""
SID=s1

# --- guards ------------------------------------------------------------------

check "a stop inside another hook's continuation is silent" \
    "$(payload t9 | sed 's/}$/,"stop_hook_active":true}/' | sh "$STOP_HOOK" 2>/dev/null)" ""

# A session that never ran the prompt hook has no baseline. Recording one and staying quiet is
# the only honest option; claiming the whole dirty tree would be the false order this exists
# to stop.
SID=fresh
end_turn u1
check "a session with no snapshot records instead of reporting" "$OUT" ""
begin_turn u2
oversized > "$WORK/repo/src/Later.cs"
end_turn u2
check "and reports normally once it has one" "$(named 'Later.cs')" "1"
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
