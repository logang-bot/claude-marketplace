#!/bin/sh
# SubagentStart hook: give every subagent the style rules its own context does not carry.
#
# A subagent starts with a fresh context and does no description matching against this
# plugin, so the skills that shape how code is written never reach it. Until now its files
# were only caught afterwards, by check-new-files.sh, once the work was already done. This
# is one of the two deterministic injections in the plugin: the rules arrive whether or not
# anything decided they were relevant. inject-plan-rules.sh is the other, covering the main
# thread, which does its writing where no SubagentStart ever fires.
#
# Assembling the rules is lib/rules.sh, shared with that hook so there is one copy of the
# frontmatter stripping and one definition of which skills are included.
#
# Injection is unconditional. Gating on agent_type would mean maintaining a list of names
# for agents this plugin does not own, and such a list fails silently: a new writing agent
# gets no rules and nothing says so.
#
# Note the client skips this injection for a subagent running with an isolated context.
# There is no way to reach one, and no signal here that it happened.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/rules.sh"
require_tools awk

HEADER='The general-code-style rules below are in force for this task. They apply to every
file and function you write, including code produced by a shell command, a heredoc, or a
generator script rather than the file editor, and an already-approved plan does not exempt
the code it produces. A hook measures them after the fact, so following them now is what
avoids the rework.'

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac

have_skills || exit 0

rules "$HEADER" | emit_context SubagentStart
exit 0
