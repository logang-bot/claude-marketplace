#!/bin/sh
# Stop hook: require the turn's own work to meet the style rules, whatever tool did the writing.
#
# check-size.sh only sees writes that carry a file path in the tool payload. A heredoc, a
# `sed -i`, a generator script, or an MCP server's own file-creation call carries none, so the
# rules used to pass over those files in silence. Git sees them regardless of the tool, so this
# hook asks git at the end of the turn instead of watching tool calls.
#
# It reports created, modified, and renamed files alike — anything the turn worked on. What
# keeps that from becoming a nag is not a narrow git query but lib/turn.sh, which diffs against
# a snapshot of the previous turn: a violation that was already sitting in the working tree is
# not this turn's work and is not reported. The old `--diff-filter=A` did the opposite job
# badly, excluding every modification while still re-reporting untracked files forever.
#
# Exits 2 with the finding on stderr. Exit 2 on Stop blocks the turn from ending, which is what
# gives the instruction any weight; stop_hook_active makes the hook stand down on the second
# attempt so it cannot loop. Every unexpected input returns 0.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/turn.sh"
require_tools awk git

MAX_FILES=40
MAX_NAMED=5   # offending files named in the line pointing at the agent

offending() {
    awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/offenders.awk"
}

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac
case $(printf '%s' "$PAYLOAD" | tr -d ' \t\n') in
    \{*) ;;
    *) exit 0 ;;
esac

[ "$(payload_value stop_hook_active)" = "true" ] && exit 0

cwd=$(payload_value cwd)
[ -n "$cwd" ] || cwd=$PWD
cwd=$(native_path "$cwd")
[ -d "$cwd" ] || exit 0

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

if ! turn_prepare; then
    printf '%s\n' "general-code-style: cannot write under \`$TURN_DIR\`, so the style hooks" \
        "cannot tell this turn's work from what was already in the tree and are not" \
        "checking anything. Set TMPDIR to a writable directory, or remove the plugin so" \
        "the gap is not mistaken for a clean bill of health." >&2
    exit 1
fi

snapshot=$(turn_snapshot_file "$(payload_value session_id)")

# No baseline means snapshot-turn.sh did not run, so there is no way to tell this turn's work
# from what was already in the tree. Recording it now makes the next turn measurable; claiming
# the whole dirty tree as this turn's work would be the false order this design exists to stop.
if [ ! -f "$snapshot" ]; then
    turn_candidates "$cwd" "$root" | turn_save "$snapshot" "$(payload_value prompt_id)"
    exit 0
fi

worked=$(turn_candidates "$cwd" "$root" | turn_changed "$snapshot" | head -n "$MAX_FILES")
[ -n "$worked" ] || exit 0

records=$(printf '%s\n' "$worked" | while read -r target; do
    [ -n "$target" ] || continue
    measure_records "$target" "$target"
done)
[ -n "$records" ] || exit 0

advisory=$(printf '%s\n' "$records" | advise_records "")
[ -n "$advisory" ] || exit 0

offenders=$(printf '%s\n' "$records" | offending | LC_ALL=C sort -u \
    | head -n "$MAX_NAMED" | tr '\n' ' ' | sed 's/ $//')

printf '%s\n' "general-code-style — required fix. You created, modified, or renamed these files this turn, and they break a rule this project enforces. Fix them now, before ending your turn:" >&2
printf '%s\n' "$advisory" | sed 's/^/- /' >&2
printf '%s\n' "That a file was already over the limit before you touched it is not a reason to skip it. You worked on it; bring it under the cap or split it. Only these files — do not go looking for other violations in the project." >&2
printf '%s\n' "Naming and doc comments are not measured above; the \`style-reviewer\` agent covers those: $offenders" >&2
exit 2
