# The plugin's own skill bodies, assembled for injection into a context that will not
# discover them on its own.
#
# Sourced by inject-rules.sh (SubagentStart) and inject-plan-rules.sh (the plan-mode
# triggers). The rules live in skills/*/SKILL.md and are read at runtime rather than
# restated here, so there is one copy to keep right. Every skill in the plugin is included
# — the directory is the list, the same way the rest of the plugin's components are
# discovered, so adding a skill adds it to every injection with no registration.
#
# The header differs by trigger: a subagent is told the rules govern the task it is starting,
# a plan is told they govern the code the plan will produce. The bodies are identical, which
# is the point of sharing this file.

RULES_SKILLS_DIR=${RULES_SKILLS_DIR:-$(dirname "$0")/../skills}

# Everything after the closing --- of the YAML frontmatter. The frontmatter is activation
# metadata for the client; the body is the rules. A file that opens with something other
# than --- has no frontmatter to strip and is passed through whole.
skill_body() {
    awk 'NR == 1 && $0 == "---" { state = 1; next }
         state == 1 && $0 == "---" { state = 2; next }
         state == 1 { next }
         { print }' "$1"
}

have_skills() {
    for skill in "$RULES_SKILLS_DIR"/*/SKILL.md; do
        [ -f "$skill" ] && return 0
    done
    return 1
}

# $1 is the header the bodies are introduced by.
rules() {
    printf '%s\n\n' "$1"
    for skill in "$RULES_SKILLS_DIR"/*/SKILL.md; do
        [ -f "$skill" ] || continue
        skill_body "$skill"
        printf '\n'
    done
}
