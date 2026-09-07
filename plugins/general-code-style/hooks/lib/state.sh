# Session state the style hooks keep between invocations, and what each piece is for.
#
# Three things live here, all under TURN_DIR, all keyed by session so two sessions in the same
# checkout never read each other's answers:
#
#   rules marker    whether this session has already been handed the full rules
#   reported set    which findings have already been raised during this request
#   outstanding     file-size findings raised and not yet resolved, for the whole session
#
# None of it is a premise the way the snapshot is. The snapshot decides whether a finding is
# the turn's to answer for, so a hook that cannot read it must say so rather than guess; these
# three only decide whether something is said twice. So every helper here degrades to "not
# recorded" and the caller carries on, which at worst repeats a line.
#
# The reported set is keyed by **request**, not by prompt_id. A request spans as many turns as
# the agent yields — a background subagent finishing wakes the session with a fresh prompt_id —
# so keying on the prompt would reset the set mid-request and raise everything a second time.

# A token from a payload is never trusted into a path.
state_token() {
    _tok=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')
    [ -n "$_tok" ] || _tok=nosession
    printf '%s' "$_tok"
}

state_file() {
    printf '%s/%s.%s\n' "$TURN_DIR" "$(state_token "$1")" "$2"
}

# Whether this planning episode has been given the design budgets. Cleared at ExitPlanMode, so
# a later round of planning is served again.
plan_marker_file() {
    state_file "$1" planned
}

# Whether this session has been given the full rules. Never cleared: the rules are injected at
# the plan-to-implementation handoff and again before the first write, and a session that hits
# both should pay for the payload once.
rules_marker_file() {
    state_file "$1" ruled
}

# True the first time it is asked for a given marker, and records that it was asked.
state_claim() {
    [ -f "$1" ] && return 1
    : > "$1" 2>/dev/null
    return 0
}

# The findings already raised during this request. $2 is the request id, so a new request
# starts with an empty set while a wake mid-request keeps the old one.
reported_file() {
    printf '%s/%s.%s.reported\n' "$TURN_DIR" "$(state_token "$1")" "$(state_token "$2")"
}

# File-size findings raised and not yet resolved, for the life of the session. Stop re-surfaces
# these as one line at every yield, because no hook can tell which yield is the last one before
# the agent hands back.
outstanding_file() {
    state_file "$1" outstanding
}

# `path` on stdin, recorded against the request that introduced it. A path already listed keeps
# its original request, so re-touching a file does not restart its clock.
outstanding_add() {
    _list=$1
    _request=$2
    [ -f "$_list" ] || : > "$_list" 2>/dev/null
    awk -F'\t' -v list="$_list" -v request="$_request" '
        BEGIN { while ((getline line < list) > 0) { split(line, f, "\t"); SEEN[f[1]] = 1 } close(list) }
        $0 != "" && !($1 in SEEN) { SEEN[$1] = 1; printf "%s\t%s\n", $1, request >> list }
    '
}

# The listed paths that still break the cap, as `path<TAB>code lines<TAB>request`.
#
# Re-measuring here does two jobs. It drops a file that was split later in the request instead of
# carrying a finding that is no longer true to the hand-back, and it lets the list empty itself as
# things get fixed. The request id rides along so the caller can decide who still needs telling:
# the request that introduced the file hears about it at every yield until it hands back, and a
# later request only if it touches the file again. Anything longer than that is nagging, and
# `sweep.sh --dirty` is the answer to "what is still outstanding" across a whole session.
outstanding_live() {
    _list=$1
    [ -f "$_list" ] || return 0
    while IFS='	' read -r _path _request; do
        [ -n "$_path" ] || continue
        [ -f "$_path" ] || continue
        measure_records "$_path" "$_path" \
            | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/keys.awk" -v emit=1 \
            | awk -v path="$_path" -v request="$_request" '
                index($0, "LINES:") == 1 { lines = substr($0, 7) }
                $0 == "FILE" { over = 1 }
                END { if (over) printf "%s\t%s\t%s\n", path, lines, request }
            '
    done < "$_list"
}
