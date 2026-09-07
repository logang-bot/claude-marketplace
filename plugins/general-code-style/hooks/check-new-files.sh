#!/bin/sh
# Stop hook: the backstop, and the place file-size findings are handed to the user.
#
# check-size.sh watches tool calls, so it only sees writes that name a file in their payload. A
# heredoc, a `sed -i`, a generator script, a subagent, or an MCP server's own file-creation call
# names none. This hook asks git instead, so it does not care what did the writing.
#
# It does two different things, and neither is the order the hook used to issue:
#
#   local findings the write-time hook never saw  ->  ordered, this being their first sighting
#   file size                                     ->  re-surfaced for the user, never ordered
#
# The reported set shared with check-size.sh is what separates them: a finding already raised at
# the write is in the set and stays quiet here, while one from a path-less write was never seen
# by anything and is ordered now. A cheap fix stays cheap whenever it surfaces; an expensive one
# is the user's call at any moment.
#
# ## Why this cannot simply repeat itself
#
# `Stop` fires at every yield, not only the last one — a background subagent finishing wakes the
# session afterwards — and no hook can tell which yield is final. Emitting the same text at each
# one would loop forever now that the answer is non-error feedback that keeps the conversation
# going. So the message is compared against the last one sent for this request and only sent
# when it has actually changed: a new file over the cap, a size that moved, a new finding. That
# terminates, and still speaks up whenever there is something new to say.
#
# ## Scope
#
# Only what this request introduced, against the snapshot lib/turn.sh keeps. A violation already
# sitting in the working tree is not this request's work and is never reported — touching one
# line of a file that has been 300 lines for months says nothing at all.
#
# Exits 0 and answers on stdout. Exit 2 blocked the turn and rendered as a hook error, which is
# what stalled agents mid-task; the finding is handed over instead.

set -u
. "$(dirname "$0")/lib/engine.sh"
. "$(dirname "$0")/lib/turn.sh"
. "$(dirname "$0")/lib/state.sh"
require_tools awk git

MAX_FILES=40

read_payload
case $PAYLOAD in
    *[!\ \	]*) ;;
    *) exit 0 ;;
esac
case $(printf '%s' "$PAYLOAD" | tr -d ' \t\n') in
    \{*) ;;
    *) exit 0 ;;
esac

# Set when another hook has blocked this stop. Ours no longer blocks, but standing down inside
# someone else's continuation is still the polite answer.
[ "$(payload_value stop_hook_active)" = "true" ] && exit 0

cwd=$(payload_value cwd)
[ -n "$cwd" ] || cwd=$PWD
cwd=$(native_path "$cwd")
[ -d "$cwd" ] || exit 0

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

if ! turn_prepare; then
    printf '%s\n' "general-code-style: cannot write under \`$TURN_DIR\`, so the style hooks" \
        "cannot tell this request's work from what was already in the tree and are not" \
        "checking anything. Set TMPDIR to a writable directory, or remove the plugin so" \
        "the gap is not mistaken for a clean bill of health." >&2
    exit 1
fi

session=$(payload_value session_id)
snapshot=$(turn_snapshot_file "$session")

# No baseline means snapshot-turn.sh did not run, so there is no way to tell this request's work
# from what was already in the tree. Recording it now makes the next one measurable; claiming the
# whole dirty tree as this request's work would be the false order this design exists to stop.
if [ ! -f "$snapshot" ]; then
    turn_candidates "$cwd" "$root" | turn_save "$snapshot" "$(payload_value prompt_id)"
    exit 0
fi

request=$(turn_request_id "$snapshot" 2>/dev/null) || request=""
[ -n "$request" ] || request=$(payload_value prompt_id)
reported=$(reported_file "$session" "$request")
outstanding=$(outstanding_file "$session")

all_worked=$(turn_candidates "$cwd" "$root" | turn_changed "$snapshot")
worked=$(printf '%s\n' "$all_worked" | head -n "$MAX_FILES")
hidden=$(( $(printf '%s\n' "$all_worked" | grep -c .) - $(printf '%s\n' "$worked" | grep -c .) ))

records=""
[ -n "$worked" ] && records=$(printf '%s\n' "$worked" | turn_introduced "$snapshot" "$cwd" "$root")

if [ -n "$records" ]; then
    printf '%s\n' "$records" | grep '^FILE	' | cut -f2 | outstanding_add "$outstanding" "$request"
    fresh=$(printf '%s\n' "$records" | awk -f "$ENGINE_LIB/limits.awk" \
        -f "$ENGINE_LIB/keys.awk" -f "$ENGINE_LIB/unseen.awk" -v set="$reported")
    unseen_local=$(printf '%s\n' "$fresh" | grep -v '^FILE	') || unseen_local=""
else
    unseen_local=""
fi

advisory=""
[ -n "$unseen_local" ] && advisory=$(printf '%s\n' "$unseen_local" | advise_records "")

# Re-measured, so a file split later in the request drops off the list instead of being carried
# to the hand-back as a finding that is no longer true.
#
# Who still needs telling: the request that introduced the file, at every yield until it hands
# back, and any later request that touches the file again. A file left oversized and then left
# alone has been mentioned already, and repeating it every request afterwards is the nagging this
# rewrite exists to end — `sweep.sh --dirty` is what answers that question across a session.
sizes=$(outstanding_live "$outstanding" \
    | awk -F'\t' -v request="$request" -v worked="$worked" '
        BEGIN { n = split(worked, w, "\n"); for (i = 1; i <= n; i++) TOUCHED[w[i]] = 1 }
        $3 == request || ($1 in TOUCHED) { print "FILE\t" $1 "\t" $2 }
      ' \
    | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/sized.awk")

[ -n "$advisory" ] || [ -n "$sizes" ] || exit 0

message=$({
    if [ -n "$advisory" ]; then
        printf '%s\n' "general-code-style — these came from writes that named no file path, so nothing saw them until now. Fix them before you finish:"
        printf '%s\n' "$advisory" | sed 's/^/- /'
        [ "$hidden" -gt 0 ] && printf '%s\n' "($hidden more changed files were not measured; this request touched more than $MAX_FILES.)"
        printf '%s\n' "Only these findings. The rest of each file, and every other file in the project, are out of scope."
        [ -n "$sizes" ] && printf '\n'
    fi
    if [ -n "$sizes" ]; then
        printf '%s\n' "general-code-style — file size, for the user rather than for you:"
        printf '%s\n' "$sizes" | sed 's/^/- /'
        printf '%s\n' "Say this in your summary before you hand back, and let the user decide. Do not split anything unless they ask. Naming and doc comments are not measured here; \`/style-check\` covers those."
    fi
})

# Nothing new to say means saying nothing, which is also what stops this repeating forever.
fingerprint=$TURN_DIR/$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_').said
printf '%s\n---\n%s\n' "$message" "$all_worked" > "$fingerprint.new" 2>/dev/null
if [ -f "$fingerprint" ] && cmp -s "$fingerprint" "$fingerprint.new"; then
    rm -f "$fingerprint.new"
    exit 0
fi
mv -f "$fingerprint.new" "$fingerprint" 2>/dev/null

printf '%s\n' "$message" | emit_context Stop
exit 0
