#!/bin/sh
# Puts the style rules in front of the main thread before it writes any code.
#
# inject-rules.sh covers subagents. Nothing covered the main conversation, where the skills reach
# the model only by description matching — the same probabilistic route injection exists to
# replace. So the main thread wrote code against rules it had not been given, and the size hooks
# reported the result afterwards. That works, but it pays for correctness in rework.
#
# It matters more than it used to. File-size findings are no longer an order to fix, only a
# report for the user to act on, which leaves injection as the only thing actually keeping files
# small. A rule that arrives before the file exists is worth more than any number that arrives
# after it.
#
# Four triggers, three payloads:
#
#   UserPromptSubmit, permission_mode == plan   -> the design budgets (lib/budget.awk)
#   PreToolUse on Skill, a brainstorming skill  -> the design budgets
#   PreToolUse on ExitPlanMode                  -> the full rules (lib/rules.sh)
#   PreToolUse on a write tool                  -> the full rules, once per session
#
# A plan needs the caps as constraints to design against; the handoff into implementation needs
# the rules themselves. `permission_mode` is a base field on every payload, so plan mode is
# detected however it was entered — including with shift+tab, which fires no ExitPlanMode call
# and would be invisible to a matcher.
#
# The write trigger is what covers an ordinary turn that never plans anything, which is most of
# them. It fires on the last moment that is still *before* the code exists, works in every
# permission mode, and costs nothing at all on a session that only reads. ExitPlanMode claims the
# same session marker, so a planned session is not charged for the payload twice.
#
# The Skill trigger is for projects that have a brainstorming plugin installed. This one does not,
# and neither does any project necessarily: the matcher fires on every Skill call and the name
# test decides whether anything is emitted.
#
# Every path exits 0. Exit 2 on UserPromptSubmit blocks the user's own prompt, and on PreToolUse
# it blocks the tool call — on ExitPlanMode or a Write that would be unusable. There is no
# injection failure worth either of those.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/rules.sh"
. "$(dirname "$0")/lib/turn.sh"
. "$(dirname "$0")/lib/state.sh"
require_tools awk

PLAN_HEADER='The general-code-style rules below are in force for the implementation you are about
to begin. The plan being approved does not exempt the code it produces: they apply to every
file and function you write, including code produced by a shell command, a heredoc, or a
generator script rather than the file editor. A hook measures them afterwards, so following
them now is what avoids the rework.'

WRITE_HEADER='The general-code-style rules below govern the file you are about to write, and
every file and function you write after it in this session — including code produced by a shell
command, a heredoc, or a generator script rather than the file editor. Function length,
parameter count, member order and comment discipline are measured after each write and you will
be asked to fix them. File length is measured too, but splitting a file afterwards is expensive,
so the place to get it right is here, before the file exists.'

budget() {
    awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/budget.awk" -v emit=1 </dev/null
}

# True the first time this session asks, and records that it asked. A session whose marker
# cannot be written is treated as unserved every time: repeating a digest is a cost, staying
# silent is a gap, and the gap is the worse of the two.
claim() {
    turn_prepare || return 0
    state_claim "$1"
}

release() {
    turn_prepare || return 0
    rm -f "$1" 2>/dev/null
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
        claim "$(plan_marker_file "$session")" || exit 0
        budget | emit_context UserPromptSubmit
        ;;
    PreToolUse)
        case $(payload_value tool_name) in
            ExitPlanMode)
                release "$(plan_marker_file "$session")"
                claim "$(rules_marker_file "$session")" || exit 0
                rules "$PLAN_HEADER" | emit_context PreToolUse
                ;;
            Write|Edit|MultiEdit|NotebookEdit)
                claim "$(rules_marker_file "$session")" || exit 0
                rules "$WRITE_HEADER" | emit_context PreToolUse
                ;;
            Skill)
                # The skill is named plugin:skill, so the plugin providing it is not known here
                # and is not worth guessing at. Matching the substring catches it under whatever
                # prefix it ships with.
                case $(case_insensitive "$(payload_value tool_input.skill)") in
                    *brainstorm*) ;;
                    *) exit 0 ;;
                esac
                claim "$(plan_marker_file "$session")" || exit 0
                budget | emit_context PreToolUse
                ;;
        esac
        ;;
esac
exit 0
