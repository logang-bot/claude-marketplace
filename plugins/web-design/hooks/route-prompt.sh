#!/bin/sh
# UserPromptSubmit hook: when a request is about web design, point the main thread at the
# personality-first workflow before it starts.
#
# The skills reach the main thread only by description matching, which is probabilistic. A
# request like "build me a landing page" is exactly where the order matters most — personality,
# then tokens, then markup — and where a model left to itself starts with markup. So a prompt that
# reads as design work gets a short pointer, once per session:
#
#   - settle the personality with the choosing-a-website-personality skill
#   - read DESIGN.md; when there is none and the request builds new pages or screens, tell the
#     user and ask whether to create it with /design-brief or let Claude decide the style
#   - in plan mode, the full rules digest too, since the plan is where the choices get made
#
# This is the one moment the question can come before any code: UserPromptSubmit context arrives
# before Claude acts, while a PreToolUse hook only speaks once its write is already under way.
# Claude judges the request's size, so a one-line colour fix is not interrupted by a question.
#
# The keyword test is deliberately broad. A false positive costs one short paragraph, once; a
# false negative costs a page designed without a personality.
#
# Every path exits 0. Exit 2 on UserPromptSubmit would block the user's own prompt.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/state.sh"
. "$(dirname "$0")/lib/rules.sh"
. "$(dirname "$0")/lib/brief.sh"
require_tools awk

PLAN_HEADER='The web-design rules below govern this plan and the code it produces. Fix the
personality and the tokens in the plan itself.'

design_intent() {
    printf '%s' "$1" | tr 'A-Z' 'a-z' | awk '
        { t = t " " $0 }
        END {
            if (t ~ /landing ?page|web ?site|web ?page|home ?page|front[- ]?end|stylesheet|tailwind|redesign|hero section|navbar|nav bar|pricing (page|table|section)|portfolio site|typography|colou?r (palette|scheme)|font|layout|user interface|look and feel|restyle|make it (look|prettier|nicer)/) exit 0
            if (t ~ /(^|[^a-z])(ui|ux|css|scss|html|design|styling|style|page|pages|screen|screens)([^a-z]|$)/) exit 0
            exit 1
        }'
}

read_payload
payload_blank && exit 0

prompt=$(payload_value prompt) || exit 0
turn_is_human_prompt "$prompt" || exit 0
design_intent "$prompt" || exit 0

session=$(payload_value session_id)
state_claim "$(state_file "$session" routed)" || exit 0

root=$(project_root "$(payload_cwd)")
# In plan mode the digest comes along, once per session. It carries the personality rules, so the
# first pointer line would only repeat it, and dropping that line keeps the payload in budget.
planning=0
[ "$(payload_value permission_mode)" = "plan" ] && have_skills \
    && state_claim "$(state_file "$session" ruled)" && planning=1
{
    printf '%s\n' "web-design: this request involves web design. Before writing markup or styles:"
    [ "$planning" = 1 ] || printf '%s\n' "- Settle the website personality first (\`choosing-a-website-personality\` skill): one of the seven, or a custom one when none fits. Every other design choice follows from it."
    if brief_file "$root" >/dev/null; then
        printf '%s\n' "- Read DESIGN.md at the project root and build with its personality and tokens. If the request changes them, update DESIGN.md first."
    else
        printf '%s\n' "- There is no DESIGN.md yet (it records the personality and tokens this plugin checks against). If this request creates a new page, screen or several components, tell the user before writing any of it and ask: create it now with \`/design-brief\`, or let you decide the style? Wait for the answer; if you decide, name the personality and tokens first. For a small UI change, just mention that \`/design-brief\` can create it."
    fi
    if [ "$planning" = 1 ]; then
        printf '\n'
        rules_digest "$PLAN_HEADER"
    else
        printf '%s\n' "- The web-design rules are injected before the first write, and every written page or stylesheet is linted afterwards."
    fi
} | emit_context UserPromptSubmit
exit 0
