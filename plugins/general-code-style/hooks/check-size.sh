#!/bin/sh
# PostToolBatch hook: warn when anything just written breaks a general-code-style rule.
#
# Reads the hook payload on stdin, measures the files the batch wrote, and exits 2 with an
# advisory on stderr when a rule is broken. Exit 2 is what surfaces the message to Claude;
# the wording makes clear it is advice, not a blocked action. Every unexpected input returns
# 0, so a malformed payload never interrupts work.
#
# PostToolBatch fires once after every call in a batch has resolved, which is why the whole
# batch is measured together: PostToolUse fires per tool and runs concurrently for parallel
# calls, so five writes in one block produced five separate advisories, each applying the
# MAX_WARNINGS cap on its own. Here the cap applies once, over the batch.
#
# No matcher is set in hooks.json, deliberately. A PostToolBatch matcher has to match every
# call in the batch, so one Read alongside a Write would skip the hook entirely; the
# write-tool filter is in lib/batch.awk instead.
#
# The single-call payload shape is still handled, so the hook works unchanged if it is ever
# registered on PostToolUse — which is the fallback if PostToolBatch turns out to be inert
# on some client.
#
# A write that names no path at all — a shell heredoc, a generator script — is invisible
# here by construction; check-new-files.sh is what covers those.

set -u
. "$(dirname "$0")/lib/engine.sh"
require_tools awk

# Tools disagree about what to call the file they wrote, and an MCP server that writes files
# picks its own name, so the common spellings are all tried, in this order.
PATH_KEYS='tool_input.file_path tool_input.notebook_path tool_input.path tool_input.filePath'

tag_lines() {
    awk -v tag="$1" 'BEGIN { FS = OFS = "\t" } { print tag, $0 }'
}

# Paths from a batch payload, filtered down to the calls that actually wrote something.
batch_paths() {
    {
        payload_values 'tool_calls[].tool_name' | tag_lines NAME
        for key in $PATH_KEYS; do
            payload_values "tool_calls[].$key" | tag_lines PATH
        done
    } | awk -f "$ENGINE_LIB/batch.awk"
}

# The single-call shape: the first spelling that names a file.
single_path() {
    for key in $PATH_KEYS; do
        found=$(payload_value "$key") || continue
        [ -n "$found" ] && printf '%s\n' "$found" && return 0
    done
    return 1
}

existing() {
    while read -r candidate; do
        [ -n "$candidate" ] || continue
        candidate=$(native_path "$candidate")
        [ -f "$candidate" ] && printf '%s\n' "$candidate"
    done
}

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac

targets=$(batch_paths | existing)
[ -n "$targets" ] || targets=$(single_path | existing)
[ -n "$targets" ] || exit 0

records=$(printf '%s\n' "$targets" | while read -r target; do
    measure_records "$target" "$target"
done)
[ -n "$records" ] || exit 0

# Naming one file is only honest when one file was measured — the same rule
# check-new-files.sh follows when it caps findings over a set.
scope=""
[ "$(printf '%s\n' "$targets" | grep -c .)" = "1" ] && scope="in this file"

advisory=$(printf '%s\n' "$records" | advise_records "$scope")
[ -n "$advisory" ] || exit 0

printf '%s\n' "general-code-style — required fix. Your write succeeded, but it leaves these breaking a rule this project enforces. Fix them now, before continuing:" >&2
printf '%s\n' "$advisory" | sed 's/^/- /' >&2
printf '%s\n' "That a file was already over the limit before you touched it is not a reason to skip it. You worked on it; bring it under the cap or split it. Only these files — do not go looking for other violations in the project." >&2
exit 2
