#!/bin/sh
# Stop hook: remind about docs/ when code changed but documentation did not.
#
# Fires at most once per turn. `stop_hook_active` in the payload means this hook already
# fired and Claude is stopping again — returning 2 there would loop forever, so it exits
# cleanly instead.

set -u
. "$(dirname "$0")/lib/hook.sh"
require_tools awk git

changed_files() {
    git -C "$1" diff --name-only HEAD 2>/dev/null || return 1
    git -C "$1" ls-files --others --exclude-standard 2>/dev/null
}

read_payload
payload_is_object || exit 0
[ "$(payload_value stop_hook_active)" = "true" ] && exit 0

cwd=$(payload_value cwd)
[ -n "$cwd" ] || cwd=$PWD
[ -d "$cwd/docs" ] || exit 0

git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0
classified=$(changed_files "$cwd" | awk -f "$HOOK_LIB/doc-rules.awk") || exit 0

case $classified in
    *__DOC__*) exit 0 ;;
esac
[ -n "$classified" ] || exit 0

count=$(printf '%s\n' "$classified" | awk 'END { print NR }')
sample=$(printf '%s\n' "$classified" | awk '
    NR <= 4 { out = (NR == 1) ? $0 : out ", " $0 }
    END { print (NR > 4) ? out " (+" NR - 4 " more)" : out }
')

printf 'Documentation check (dev-workflow): %s code file(s) changed with no documentation change — %s.\n\n' "$count" "$sample" >&2
printf '%s\n' "If this change altered behaviour, update the doc that covers it and grep docs/ for claims it made stale. If it was an internal refactor, a test, or formatting, no doc update is needed — say so in one line and stop." >&2
exit 2
