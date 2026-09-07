#!/bin/sh
# PostToolBatch hook: answer for what a write just introduced, at the moment it is cheapest.
#
# Two jobs, and the split between them is the whole design:
#
#   function size, parameter count, in-body comments  ->  ordered, fixed here and now
#   file size                                         ->  reported, for the user to decide
#
# The first three are local. They are complete the instant the function is written, and fixing
# one is an extraction inside a file the agent still has in hand — a lint, not a task switch.
# File size is neither: a file is not finished mid-request, and splitting one means moving
# members and chasing call sites across the project. Ordering that here is what derailed work
# and stalled turns, so the size is stated and handed to the user instead.
#
# Reporting it here rather than only at Stop is not cosmetic. Stop runs *after* the model has
# composed its hand-back summary, so anything first delivered there can only be a follow-up
# message. Told at the write, the model has the fact in context while it is still working and
# can put it in the summary itself.
#
# Only what this request introduced is reported at all; lib/introduced.awk holds that rule.
# Without a git baseline — a directory that is not a repository — inherited findings cannot be
# told from new ones, so the local findings are still reported, being cheap to fix and probably
# the agent's own, and file size is dropped, being the expensive one to be wrong about.
#
# PostToolBatch fires once after every call in a batch has resolved, which is why the whole
# batch is measured together: PostToolUse fires per tool and runs concurrently for parallel
# calls, so five writes in one block produced five separate advisories, each applying the
# MAX_WARNINGS cap on its own. Here the cap applies once, over the batch.
#
# No matcher is set in hooks.json, deliberately. A PostToolBatch matcher has to match every
# call in the batch, so one Read alongside a Write would skip the hook entirely; the write-tool
# filter is in lib/batch.awk instead.
#
# The single-call payload shape is still handled, so the hook works unchanged if it is ever
# registered on PostToolUse — which is the fallback if PostToolBatch turns out to be inert.
#
# A write that names no path at all — a shell heredoc, a generator script — is invisible here by
# construction; check-new-files.sh is what covers those.
#
# Exits 0 and answers on stdout. Exit 2 would render this as a hook error, which a style finding
# is not.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/turn.sh"
. "$(dirname "$0")/lib/state.sh"
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

# No state means no baseline and no way to tell a repeat from a first sighting. check-new-files.sh
# reports that condition once per turn; repeating it on every write would be noise.
turn_prepare || exit 0

cwd=$(payload_value cwd)
[ -n "$cwd" ] || cwd=$PWD
cwd=$(native_path "$cwd")
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=""

session=$(payload_value session_id)
snapshot=$(turn_snapshot_file "$session")
request=$(turn_request_id "$snapshot" 2>/dev/null) || request=""
[ -n "$request" ] || request=$(payload_value prompt_id)
reported=$(reported_file "$session" "$request")

records=$(printf '%s\n' "$targets" | turn_introduced "$snapshot" "$cwd" "$root")
[ -n "$records" ] || exit 0

fresh=$(printf '%s\n' "$records" | awk -f "$ENGINE_LIB/limits.awk" \
    -f "$ENGINE_LIB/keys.awk" -f "$ENGINE_LIB/unseen.awk" -v set="$reported")

local_records=$(printf '%s\n' "$fresh" | grep -v '^FILE	') || local_records=""
if [ -n "$root" ]; then
    sized_records=$(printf '%s\n' "$fresh" | grep '^FILE	') || sized_records=""
    printf '%s\n' "$records" | grep '^FILE	' | cut -f2 \
        | outstanding_add "$(outstanding_file "$session")" "$request"
else
    sized_records=""
fi

# Naming one file is only honest when one file was measured — the same rule check-new-files.sh
# follows when it caps findings over a set.
scope=""
[ "$(printf '%s\n' "$targets" | grep -c .)" = "1" ] && scope="in this file"

advisory=""
[ -n "$local_records" ] && advisory=$(printf '%s\n' "$local_records" | advise_records "$scope")
sizes=""
[ -n "$sized_records" ] && sizes=$(printf '%s\n' "$sized_records" \
    | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/sized.awk")

[ -n "$advisory" ] || [ -n "$sizes" ] || exit 0

{
    if [ -n "$advisory" ]; then
        printf '%s\n' "general-code-style — this write introduced the following. Fix them now, while the file is still in hand:"
        printf '%s\n' "$advisory" | sed 's/^/- /'
        printf '%s\n' "Only these findings. The rest of the file, and every other file in the project, are out of scope."
        [ -n "$sizes" ] && printf '\n'
    fi
    if [ -n "$sizes" ]; then
        printf '%s\n' "general-code-style — file size, for the user rather than for you:"
        printf '%s\n' "$sizes" | sed 's/^/- /'
        printf '%s\n' "Do not split it now — the file is not finished, and splitting one mid-implementation derails the work you were asked to do. Tell the user about it when you hand back, and let them decide."
    fi
} | emit_context PostToolBatch
exit 0
