#!/bin/sh
# SubagentStart hook: give every subagent the style rules its own context does not carry.
#
# A subagent starts with a fresh context and does no description matching against this
# plugin, so the skills that shape how code is written never reach it. Until now its files
# were only caught afterwards, by check-new-files.sh, once the work was already done. This
# is the one part of the plugin that is deterministic rather than advisory: the rules arrive
# whether or not anything decided they were relevant.
#
# The rules are read from the plugin's own SKILL.md bodies rather than restated here, so
# there is one copy to keep right. Every skill in the plugin is included — the directory is
# the list, the same way the rest of the plugin's components are discovered.
#
# Injection is unconditional. Gating on agent_type would mean maintaining a list of names
# for agents this plugin does not own, and such a list fails silently: a new writing agent
# gets no rules and nothing says so.
#
# Note the client skips this injection for a subagent running with an isolated context.
# There is no way to reach one, and no signal here that it happened.

set -u
. "$(dirname "$0")/lib/engine.sh"
require_tools awk

SKILLS_DIR=$(dirname "$0")/../skills

HEADER='The general-code-style rules below are in force for this task. They apply to every
file and function you write, including code produced by a shell command, a heredoc, or a
generator script rather than the file editor, and an already-approved plan does not exempt
the code it produces. A hook measures them after the fact, so following them now is what
avoids the rework.'

# Everything after the closing --- of the YAML frontmatter. The frontmatter is activation
# metadata for the client; the body is the rules. A file that opens with something other
# than --- has no frontmatter to strip and is passed through whole.
skill_body() {
    awk 'NR == 1 && $0 == "---" { state = 1; next }
         state == 1 && $0 == "---" { state = 2; next }
         state == 1 { next }
         { print }' "$1"
}

rules() {
    printf '%s\n\n' "$HEADER"
    for skill in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$skill" ] || continue
        skill_body "$skill"
        printf '\n'
    done
}

have_skills() {
    for skill in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$skill" ] && return 0
    done
    return 1
}

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac

have_skills || exit 0

rules | emit_context SubagentStart
exit 0
