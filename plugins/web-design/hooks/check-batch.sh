#!/bin/sh
# PostToolBatch hook: lint the pages and stylesheets a batch of writes just produced, while the
# agent still has them in hand.
#
# Scope is what the batch introduced:
#
#   Write      the whole file is the agent's work, so every finding in it counts
#   Edit       only findings on lines the edit wrote (lib/introduced.awk); a justified paragraph
#              the file has carried for years is not this edit's business
#
# A finding already raised this request is not raised again (lib/seen.awk), and the list is
# capped and ordered by how much each rule matters to a reader (lib/report.awk), so a stylesheet
# full of off-scale paddings cannot crowd out a contrast failure.
#
# No matcher in hooks.json, deliberately: a PostToolBatch matcher must match every call in the
# batch, so one Read beside a Write would skip the hook. lib/batch.awk filters for writes instead.
# The single-call payload shape is handled too, so the hook also works registered on PostToolUse.
#
# Exits 0 and answers on stdout. Findings are advisory: a rule bent on purpose for the chosen
# personality can be kept with a one-line reason.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/state.sh"
. "$(dirname "$0")/lib/brief.sh"
require_tools awk

PATH_KEYS='tool_input.file_path tool_input.path tool_input.filePath'

tag_lines() {
    awk -v tag="$1" 'BEGIN { FS = OFS = "\t" } { print tag, $0 }'
}

# `tool\tpath` for each write in a batch payload, else for the single-call shape.
written() {
    _out=$({
        payload_values 'tool_calls[].tool_name' | tag_lines NAME
        for _key in $PATH_KEYS; do
            payload_values "tool_calls[].$_key" | tag_lines PATH
        done
    } | awk -f "$ENGINE_LIB/batch.awk")
    if [ -n "$_out" ]; then printf '%s\n' "$_out"; return 0; fi
    _tool=$(payload_value tool_name) || return 0
    for _key in $PATH_KEYS; do
        _found=$(payload_value "$_key") || continue
        [ -n "$_found" ] && printf '%s\t%s\n' "$_tool" "$_found" && return 0
    done
    return 0
}

# Every new_string in the payload, one line of text per line, whatever shape it arrived in.
new_strings() {
    for _key in 'tool_calls[].tool_input.new_string' 'tool_calls[].tool_input.edits[].new_string' \
        'tool_input.new_string' 'tool_input.edits[].new_string'; do
        payload_values_nl "$_key" | cut -f2-
    done | tr '\034' '\n'
}

read_payload
payload_blank && exit 0

writes=$(written | awk -F'\t' '$1 ~ /^(Write|Edit|MultiEdit)$/' | while IFS='	' read -r tool p; do
    p=$(native_path "$p")
    [ -f "$p" ] && is_web_path "$p" && printf '%s\t%s\n' "$tool" "$p"
done)
[ -n "$writes" ] || exit 0

turn_prepare || exit 0
session=$(payload_value session_id)
snapshot=$(state_file "$session" snapshot)
request=$(turn_request_id "$snapshot" 2>/dev/null) || request=""
[ -n "$request" ] || request=$(payload_value prompt_id)

work=$(state_file "$session" batch.$$)
printf '%s\n' "$writes" | awk -F'\t' '$1 != "Write" { print $2 }' > "$work.edited"
new_strings > "$work.pool"

root=$(project_root "$(payload_cwd)")
advisory=$(printf '%s\n' "$writes" | cut -f2 | awk '!seen[$0]++' | lint_files "$root" \
    | awk -f "$ENGINE_LIB/common.awk" -f "$ENGINE_LIB/introduced.awk" -v pool="$work.pool" -v edited="$work.edited" \
    | unseen_findings "$(reported_file "$session" "$request")" \
    | report_findings "$root" 8)
rm -f "$work.edited" "$work.pool" 2>/dev/null

[ -n "$advisory" ] || exit 0
{
    printf '%s\n' "web-design — this write introduced the following. Fix them now, while the file is still in hand:"
    printf '%s\n' "$advisory" | sed 's/^/- /'
    printf '%s\n' "Only these findings; the rest of the file is out of scope. If one is a deliberate choice for the website personality or DESIGN.md, keep it and say why in one line."
} | emit_context PostToolBatch
exit 0
