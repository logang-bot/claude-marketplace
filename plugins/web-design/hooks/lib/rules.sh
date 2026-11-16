# The rules digest: every `## Rules: ...` section of the plugin's own skills, assembled for
# injection into a context that will not discover the skills on its own.
#
# The skills are the one copy of the rules. Each SKILL.md keeps its terse numbered rules under a
# `## Rules: <Area> (<ID>)` heading and its longer guidance under other headings, so the digest
# can carry all ten areas inside the 7000-character budget while the skill bodies stay free to
# explain. The directory is the list: a new skill with a Rules section joins every injection.

RULES_SKILLS_DIR=${RULES_SKILLS_DIR:-$(dirname "$0")/../skills}

have_skills() {
    for _skill in "$RULES_SKILLS_DIR"/*/SKILL.md; do
        [ -f "$_skill" ] && return 0
    done
    return 1
}

# The order the areas are read in: the personality that drives everything, then the
# guidelines' own order. A skill not in the list still joins, after these.
RULES_ORDER='choosing-a-website-personality setting-typography building-color-palettes
using-images-and-illustrations using-icons applying-shadows-and-radius spacing-with-whitespace
establishing-visual-hierarchy designing-for-user-experience composing-components-and-layouts'

# The Rules sections of one skill, each heading turned into `### <Area> (<ID>)`.
rules_sections() {
    awk '
        /^## Rules:/ { on = 1; h = $0; sub(/^## Rules:[ ]*/, "", h); print "### " h; next }
        /^## / { on = 0 }
        on && NF { print }
    ' "$1"
}

# $1 is the header the sections are introduced by.
rules_digest() {
    printf '%s\n\n' "$1"
    for _name in $RULES_ORDER; do
        [ -f "$RULES_SKILLS_DIR/$_name/SKILL.md" ] && rules_sections "$RULES_SKILLS_DIR/$_name/SKILL.md"
    done
    for _skill in "$RULES_SKILLS_DIR"/*/SKILL.md; do
        [ -f "$_skill" ] || continue
        case " $(printf '%s' "$RULES_ORDER" | tr '\n' ' ') " in
            *" $(basename "$(dirname "$_skill")") "*) continue ;;
        esac
        rules_sections "$_skill"
    done
}
