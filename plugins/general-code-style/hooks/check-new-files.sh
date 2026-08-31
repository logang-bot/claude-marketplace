#!/bin/sh
# Stop hook: measure source files this turn created, whatever tool created them.
#
# check-size.sh only sees writes that carry a file path in the tool payload. A heredoc, a
# sed -i, a generator script, or an MCP server's own file-creation call carries none, so
# the size rules used to pass over those files in silence. Git sees them regardless of the
# tool, so this hook asks git at the end of the turn instead of watching tool calls.
#
# Only files git reports as new are measured. Modifications are left alone deliberately: a
# dirty working tree full of pre-existing violations would otherwise re-warn every turn.
#
# Exits 2 with an advisory on stderr, the same as check-size.sh — the file already exists,
# so the message is advice, not a rejection. Every unexpected input returns 0.

set -u
. "$(dirname "$0")/lib/engine.sh"
require_tools awk git

MAX_FILES=40

# The extension filter reads its scope from limits.awk rather than restating it, so the
# hook and the sweep can never disagree about what counts as a source file.
in_scope() {
    awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/scope.awk"
}

# Untracked files plus staged additions — the two ways a file is new to git.
new_files() {
    git -C "$1" ls-files --others --exclude-standard 2>/dev/null
    git -C "$1" diff --name-only --diff-filter=A HEAD 2>/dev/null
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

records=$(
    new_files "$cwd" | LC_ALL=C sort -u | in_scope | head -n "$MAX_FILES" | while read -r name; do
        [ -f "$root/$name" ] || continue
        measure_records "$root/$name" "$root/$name"
    done
)
[ -n "$records" ] || exit 0

advisory=$(printf '%s\n' "$records" | advise_records "")
[ -n "$advisory" ] || exit 0

printf '%s\n' "Style advisory (general-code-style) — a file created this turn breaks a style rule. The write already succeeded; address this before moving on:" >&2
printf '%s\n' "$advisory" | sed 's/^/- /' >&2
exit 2
