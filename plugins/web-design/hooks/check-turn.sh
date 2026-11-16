#!/bin/sh
# Stop hook: the backstop for writes no tool payload named, the cross-file checks, and the
# pointer to the judgement review.
#
# check-batch.sh only sees writes whose payload names a file. A heredoc, a `sed -i`, a generator,
# a subagent's own edits name none, so this hook asks git instead: every web file whose content
# differs from the snapshot taken when the request began is linted together, which is also where
# mixing icon packs or adding a third typeface across files shows up.
#
# The linter cannot judge hierarchy, image relevance, whitespace grouping, CTA prominence or
# personality fit. Those belong to the design-reviewer and ux-reviewer agents behind
# /design-audit. The hook does not start them — a subagent spawned as the turn ends is the pattern
# this marketplace already removed — it asks Claude to mention the command in its hand-back.
#
# ## Not repeating itself
#
# Stop fires at every yield, and additionalContext keeps the conversation going, so a hook that
# said the same thing at each yield would loop. Two things make this one terminate: a finding is
# recorded in the reported set the moment it is told (shared with check-batch.sh, so a finding
# told at the write is not told here either), and the /design-audit pointer is given once per
# request. A yield with nothing new to say says nothing.
#
# Exits 0 and answers on stdout; nothing here blocks.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/state.sh"
. "$(dirname "$0")/lib/brief.sh"
require_tools awk git cksum

MAX_FILES=40

read_payload
payload_blank && exit 0
[ "$(payload_value stop_hook_active)" = "true" ] && exit 0

cwd=$(payload_cwd)
[ -d "$cwd" ] || exit 0
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
turn_prepare || exit 0

session=$(payload_value session_id)
snapshot=$(state_file "$session" snapshot)

# No baseline means snapshot-turn.sh never ran, so this request's work cannot be told from what
# was already dirty. Take one now so the next request is measurable, and claim nothing.
if [ ! -f "$snapshot" ]; then
    turn_candidates "$root" | turn_save "$snapshot" "$(payload_value prompt_id)"
    exit 0
fi

request=$(turn_request_id "$snapshot" 2>/dev/null) || request=""
[ -n "$request" ] || request=$(payload_value prompt_id)

changed=$(turn_candidates "$root" | turn_changed "$snapshot" | head -n "$MAX_FILES")
[ -n "$changed" ] || exit 0

advisory=$(printf '%s\n' "$changed" | lint_files "$root" \
    | unseen_findings "$(reported_file "$session" "$request")" \
    | report_findings "$root" 8)

count=$(printf '%s\n' "$changed" | grep -c .)
pointed=$(reported_file "$session" "$request").pointed
point=0
state_claim "$pointed" && point=1
[ -n "$advisory" ] || [ "$point" = 1 ] || exit 0

{
    if [ -n "$advisory" ]; then
        printf '%s\n' "web-design — across the $count page(s) and stylesheet(s) this request changed, these were not reported at the write. Fix them before you finish:"
        printf '%s\n' "$advisory" | sed 's/^/- /'
        [ "$point" = 1 ] && printf '\n'
    fi
    if [ "$point" = 1 ]; then
        printf '%s\n' "web-design — the lint covers measurable rules only. Hierarchy, image relevance, whitespace grouping, CTA prominence and personality fit need judgement: in your summary, tell the user \`/design-audit\` reviews them. Do not start that review yourself."
    fi
} | emit_context Stop
exit 0
