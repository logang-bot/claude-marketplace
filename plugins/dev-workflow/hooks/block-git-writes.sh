#!/bin/sh
# PreToolUse hook: deny git commands that write history or publish.
#
# Exit 2 blocks the tool call; stderr becomes the reason shown to Claude.
# Read-only git commands pass through untouched.

set -u
. "$(dirname "$0")/lib/hook.sh"
require_tools awk

read_payload
payload_is_object || exit 0
[ "$(payload_value tool_name)" = "Bash" ] || exit 0

command=$(payload_value tool_input.command) || exit 0
[ -n "$command" ] || exit 0

violation=$(printf '%s' "$command" | awk -f "$HOOK_LIB/git-rules.awk") || exit 0
[ -n "$violation" ] || exit 0

printf 'Blocked: `%s` — the developer runs all git write commands themselves.\n\n' "$violation" >&2
printf '%s\n' "This is policy, not a failure. Finish the file edits, then stop and tell the user exactly what to run, including the commit message you would have used. Do not work around this with gh, an alias, or a script. Read-only git commands (status, diff, log, show) are allowed." >&2
exit 2
