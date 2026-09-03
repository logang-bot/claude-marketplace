# The caps as design constraints, for injection while work is being planned.
#
#   awk -f limits.awk -f budget.awk </dev/null
#
# A plan needs the numbers and what to do about them; the full rules are a different
# payload, injected at the plan-to-implementation handoff by the same hook. This one is
# deliberately small — it is spent on every planning episode, and a digest that costs as
# much as the rules it summarises would have no reason to exist.
#
# The numbers are read from limits.awk rather than written out here, for the reason the
# injection hooks read skills/*/SKILL.md rather than restating the rules: raising a cap
# should reach every consumer from one edit. Prose that would go stale if a limit moved
# belongs in the SKILL.md bodies, not in this file.
#
# The BEGIN block is guarded by `emit` so that loading this module alongside its siblings —
# which CI does, to catch a name used as a function in one file and a variable in another —
# neither prints nor short-circuits their END blocks.
#
# The targets behind the caps (~200 lines, ~7-line bodies) are deliberately absent. This
# text states what is enforced and will block a turn; the full rules carry the aim.

BEGIN {
    if (emit == "") exit          # loaded for a parse check, not to produce anything

    init_limits()

    printf "general-code-style — design budgets for this plan.\n\n"
    printf "The code this plan produces will be measured against these caps, by a hook that\n"
    printf "blocks the turn from ending until they are met:\n\n"
    printf "  source file    %4d lines   (imports and package lines are not counted)\n", FILE_LIMIT
    printf "  function body  %4d lines   (blank lines and comments are not counted)\n", FUNCTION_LIMIT
    printf "  parameters     %4d         (group the extras into a type beyond that)\n\n", PARAM_LIMIT
    printf "Plan around them, not against them. If a file this plan calls for would land over\n"
    printf "the line cap, plan the split now and name the pieces — discovering it at write time\n"
    printf "means refactoring code you have just written. If a function you are describing needs\n"
    printf "more than %d inputs, name the type that groups them here.\n\n", PARAM_LIMIT
    printf "Explanatory comments inside a function body are a defect in this project, not a\n"
    printf "courtesy. A plan step reading \"add a comment explaining X\" should read \"name it so\n"
    printf "X is obvious\".\n\n"
    printf "UI component functions — Compose composables, React components, SwiftUI views — are\n"
    printf "exempt from the body and parameter caps, and from those two only. File length is not\n"
    printf "exempt, and neither is the comment rule.\n"
    exit
}
