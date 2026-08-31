#!/bin/sh
# PostToolUse hook: warn when a written file breaks a general-code-style rule.
#
# Reads the hook payload on stdin, measures the file that was just written, and exits 2
# with an advisory on stderr when a rule is broken. Exit 2 is what surfaces the message to
# Claude; the wording makes clear it is advice, not a blocked action. Every unexpected
# input returns 0, so a malformed payload never interrupts work.
#
# Tools disagree about what to call the file they wrote, and an MCP server that writes
# files picks its own name, so the common spellings are all tried. A write that names no
# path at all — a shell heredoc, a generator script — is invisible here by construction;
# check-new-files.sh is what covers those.

set -u
. "$(dirname "$0")/lib/engine.sh"
require_tools awk

written_path() {
    for key in tool_input.file_path tool_input.notebook_path tool_input.path \
               tool_input.filePath; do
        found=$(payload_value "$key") || continue
        [ -n "$found" ] || continue
        found=$(native_path "$found")
        [ -f "$found" ] && printf '%s\n' "$found" && return 0
    done
    return 1
}

read_payload
target=$(written_path) || exit 0

advisory=$(measure_records "$target" "$target" | advise_records "in this file")
[ -n "$advisory" ] || exit 0

printf '%s\n' "Style advisory (general-code-style) — the write succeeded; consider addressing this before moving on:" >&2
printf '%s\n' "$advisory" | sed 's/^/- /' >&2
exit 2
