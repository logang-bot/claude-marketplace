#!/bin/sh
# Puts the style rules in front of the main thread while the work is still being planned.
#
# inject-rules.sh covers subagents. Nothing covered the main conversation, where the skills
# reach the model only by description matching — the same probabilistic route that injection
# exists to replace. So the main thread wrote code against rules it had not been given, and
# check-size.sh and check-new-files.sh ordered the fix afterwards. That works, but it pays for
# correctness in rework: a file is written, measured, and then split. Planning is the moment
# the same correction is free, because no code exists yet.
#
# Three triggers, two payloads:
#
#   UserPromptSubmit, permission_mode == plan   -> the design budgets (lib/budget.awk)
#   PreToolUse on Skill, a brainstorming skill  -> the design budgets
#   PreToolUse on ExitPlanMode                  -> the full rules (lib/rules.sh)
#
# A plan needs the caps as constraints to design against; the handoff into implementation
# needs the rules themselves. permission_mode is a base field on every payload, so plan mode
# is detected however it was entered — including with shift+tab, which fires no EnterPlanMode
# tool call and would be invisible to a matcher.
#
# The Skill trigger is for projects that have a brainstorming plugin installed. This one does
# not, and neither does any project necessarily: the matcher fires on every Skill call and the
# name test decides whether anything is emitted, so a project without such a skill sees a hook
# that reads its payload and exits silently.
#
# Every path exits 0. Exit 2 on UserPromptSubmit blocks the user's own prompt, and on
# PreToolUse it blocks the tool call — on ExitPlanMode that would make plan mode unusable.
# There is no injection failure worth either of those.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/rules.sh"
. "$(dirname "$0")/lib/turn.sh"
require_tools awk

HEADER='The general-code-style rules below are in force for the implementation you are about
to begin. The plan being approved does not exempt the code it produces: they apply to every
file and function you write, including code produced by a shell command, a heredoc, or a
generator script rather than the file editor. A hook measures them afterwards and blocks the
turn until they pass, so following them now is what avoids the rework.'

budget() {
    awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/budget.awk" -v emit=1 </dev/null
}

# True when this planning episode has not been given the budgets yet, and records that it has.
# A session whose marker cannot be written is treated as unserved every time: repeating a
# digest is a cost, staying silent is a gap, and the gap is the worse of the two.
episode_unserved() {
    turn_prepare || return 0
    _marker=$(plan_marker_file "$1")
    [ -f "$_marker" ] && return 1
    : > "$_marker" 2>/dev/null
    return 0
}

episode_end() {
    turn_prepare || return 0
    rm -f "$(plan_marker_file "$1")" 2>/dev/null
    return 0
}

case_insensitive() {
    printf '%s' "$1" | tr 'A-Z' 'a-z'
}

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac

have_skills || exit 0

event=$(payload_value hook_event_name)
session=$(payload_value session_id)

case $event in
    UserPromptSubmit)
        [ "$(payload_value permission_mode)" = "plan" ] || exit 0
        episode_unserved "$session" || exit 0
        budget | emit_context UserPromptSubmit
        ;;
    PreToolUse)
        case $(payload_value tool_name) in
            ExitPlanMode)
                episode_end "$session"
                rules "$HEADER" | emit_context PreToolUse
                ;;
            Skill)
                # The skill is named plugin:skill, so the plugin providing it is not known
                # here and is not worth guessing at. Matching the substring catches it under
                # whatever prefix it ships with.
                case $(case_insensitive "$(payload_value tool_input.skill)") in
                    *brainstorm*) ;;
                    *) exit 0 ;;
                esac
                episode_unserved "$session" || exit 0
                budget | emit_context PreToolUse
                ;;
        esac
        ;;
esac
exit 0
