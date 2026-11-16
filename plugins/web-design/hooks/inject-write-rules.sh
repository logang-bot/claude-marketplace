#!/bin/sh
# PreToolUse hook: put the design rules in front of the main thread at the last moment that is
# still before the page exists.
#
#   Write / Edit / MultiEdit on markup or a stylesheet  -> the rules digest, once per session
#   ... and no DESIGN.md                                  -> creating a new file: ask the user,
#                                                          once per session, whether to create it
#                                                          or let Claude decide the style;
#                                                          editing an existing one: a one-line
#                                                          mention alongside the digest
#   ExitPlanMode, after a design prompt was seen         -> the rules digest, once per session
#
# The write trigger covers the ordinary turn that never plans, which is most of them, in every
# permission mode, and costs nothing in a session that only reads or only touches backend code:
# a plain .ts or .js file is not a trigger, only markup and stylesheets are. ExitPlanMode claims
# the same marker, so a planned session pays for the digest once.
#
# The question is a backstop. route-prompt.sh asks before any code when a prompt reads as design
# work; this catches a session whose prompt did not, at the first new page or stylesheet. Context
# here arrives as the write runs, so the question lands after that one file, not before it, and it
# tells Claude to skip it when the user has already answered this session.
#
# Every path exits 0. Exit 2 on PreToolUse blocks the tool call, and there is no injection
# failure worth blocking a Write over.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/state.sh"
. "$(dirname "$0")/lib/rules.sh"
. "$(dirname "$0")/lib/brief.sh"
require_tools awk

WRITE_HEADER='The web-design rules below govern this page or stylesheet and every later one this session,
however it is written. Each written file is linted and findings come back while it is in hand.'

PLAN_HEADER='The web-design rules below are in force for the implementation you are about to
begin. The plan being approved does not exempt the code it produces.'

ASK='web-design: there is no DESIGN.md yet. Unless you already asked this session, tell the user
and ask: create it now with `/design-brief`, or let you decide the style (then name the
personality and tokens)? Wait for the answer before writing more pages. If they answered, follow it.'

MENTION='web-design: no DESIGN.md yet; mention in one line that `/design-brief` can create one.'

PATH_KEYS='tool_input.file_path tool_input.path tool_input.filePath'

target_path() {
    for _key in $PATH_KEYS; do
        _found=$(payload_value "$_key") || continue
        [ -n "$_found" ] && native_path "$_found" && return 0
    done
    return 1
}

read_payload
payload_blank && exit 0
have_skills || exit 0

session=$(payload_value session_id)

case $(payload_value tool_name) in
    ExitPlanMode)
        [ -f "$(state_file "$session" routed)" ] || exit 0
        state_claim "$(state_file "$session" ruled)" || exit 0
        rules_digest "$PLAN_HEADER" | emit_context PreToolUse
        ;;
    Write|Edit|MultiEdit)
        target=$(target_path) || exit 0
        is_design_path "$target" || exit 0
        root=$(project_root "$(payload_cwd)")
        digest=0
        state_claim "$(state_file "$session" ruled)" && digest=1
        nudge=""
        if ! brief_file "$root" >/dev/null; then
            if [ ! -e "$target" ] && state_claim "$(state_file "$session" nudged)"; then
                nudge=$ASK
            elif [ "$digest" = 1 ]; then
                nudge=$MENTION
            fi
        fi
        [ "$digest" = 1 ] || [ -n "$nudge" ] || exit 0
        {
            [ -n "$nudge" ] && printf '%s\n\n' "$nudge"
            [ "$digest" = 1 ] && rules_digest "$WRITE_HEADER"
        } | emit_context PreToolUse
        ;;
esac
exit 0
