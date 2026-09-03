#!/bin/sh
# UserPromptSubmit hook: record the state of the tree before the turn does anything to it.
#
# This is the baseline check-new-files.sh measures against at Stop. Taking it here rather than
# at the end of the previous turn is what lets the very first turn of a session be checked at
# all — a snapshot written at Stop would leave turn one with nothing to compare to, and turn
# one is often the one that creates the files.
#
# It records only what git already reports as differing from HEAD, so a clean tree snapshots
# nothing and the file stays small.
#
# It never fails loudly. Exit 2 on UserPromptSubmit would block the user's prompt, which is a
# far worse outcome than a missed measurement, so every path here returns 0; check-new-files.sh
# is where a missing snapshot is reported.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/turn.sh"
require_tools awk git

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac

cwd=$(payload_value cwd)
[ -n "$cwd" ] || cwd=$PWD
cwd=$(native_path "$cwd")
[ -d "$cwd" ] || exit 0

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

turn_prepare || exit 0

snapshot=$(turn_snapshot_file "$(payload_value session_id)")
turn_candidates "$cwd" "$root" | turn_save "$snapshot" "$(payload_value prompt_id)"
exit 0
