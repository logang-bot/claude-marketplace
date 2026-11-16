#!/bin/sh
# SubagentStart hook: give a subagent working on a web project the design rules its own context
# does not carry.
#
# A subagent starts fresh and does no description matching against this plugin, so the skills
# never reach it. Unlike general-code-style, whose rules apply to every file in every project,
# these rules only matter where there is something to design, so injection is gated on the
# project: it must contain markup or stylesheets, or a DESIGN.md. That keeps an Explore agent in
# a backend repository from paying for a typography digest.
#
# The gate looks at the project, not at the agent type. A list of "agents that write UI" would
# fail silently the day a new one appears.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/rules.sh"
require_tools awk

HEADER='The web-design rules below are in force for this task, for every page, component and stylesheet,
however it is written. Settle the website personality first (DESIGN.md records it when present)
and derive every other choice from it. Written files are linted afterwards.'

# Whether the project holds anything to design. Tracked and untracked files both count, so a
# project whose first page has not been committed yet is still recognised.
project_has_web() {
    [ -f "$1/DESIGN.md" ] && return 0
    if git -C "$1" rev-parse --git-dir >/dev/null 2>&1; then
        _hit=$(git -C "$1" ls-files -co --exclude-standard -- '*.css' '*.scss' '*.less' '*.html' \
            '*.htm' '*.vue' '*.svelte' '*.astro' '*.jsx' '*.tsx' 2>/dev/null | head -n 1)
    else
        _hit=$(find "$1" -maxdepth 3 -name node_modules -prune -o \( -name '*.css' -o -name '*.scss' \
            -o -name '*.html' -o -name '*.vue' -o -name '*.svelte' -o -name '*.jsx' -o -name '*.tsx' \) \
            -print 2>/dev/null | head -n 1)
    fi
    [ -n "$_hit" ]
}

read_payload
payload_blank && exit 0
have_skills || exit 0

root=$(project_root "$(payload_cwd)")
project_has_web "$root" || exit 0

rules_digest "$HEADER" | emit_context SubagentStart
exit 0
