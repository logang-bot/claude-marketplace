#!/bin/sh
# UserPromptSubmit hook: record the web files the tree already had changed before this request.
#
# check-turn.sh lints what the request changed, and it can only tell that from a baseline taken
# before the request did anything. The baseline is a cksum of every web file git reports as
# differing from HEAD or untracked, so a page someone else left dirty is not this request's work
# unless the request changes it again.
#
# It is retaken only on prompts a human typed. A background task finishing wakes the session with
# a prompt nobody typed, and re-snapshotting there would fold the work in flight into the
# baseline, where nothing would ever lint it.
#
# Every path exits 0: exit 2 on UserPromptSubmit would block the user's own prompt.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/state.sh"
require_tools awk git cksum

read_payload
payload_blank && exit 0

cwd=$(payload_cwd)
[ -d "$cwd" ] || exit 0
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
turn_prepare || exit 0

session=$(payload_value session_id)
snapshot=$(state_file "$session" snapshot)

if [ -f "$snapshot" ] && ! turn_is_human_prompt "$(payload_value prompt)"; then
    exit 0
fi

# The findings already raised belong to the request that is ending.
previous=$(turn_request_id "$snapshot" 2>/dev/null) || previous=""
if [ -n "$previous" ]; then
    rm -f "$(reported_file "$session" "$previous")" "$(reported_file "$session" "$previous").pointed" 2>/dev/null
fi

turn_candidates "$root" | turn_save "$snapshot" "$(payload_value prompt_id)"
exit 0
