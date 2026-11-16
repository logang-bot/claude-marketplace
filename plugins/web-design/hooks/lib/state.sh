# Session state the design hooks keep between invocations. Everything lives under TURN_DIR,
# keyed by session, so two sessions in one checkout never read each other's answers.
#
#   <sid>.snapshot              cksum of every dirty web file when the request began
#   <sid>.ruled                 the rules digest has been injected this session
#   <sid>.routed                design intent was seen in a prompt this session
#   <sid>.nudged                the create-DESIGN.md-or-let-Claude-decide question has been asked at a write
#   <sid>.<request>.reported    finding keys already raised during this request
#   <sid>.<request>.reported.pointed   the /design-audit pointer has been given this request
#
# Only the snapshot is a premise: without it Stop cannot tell this request's work from what was
# already in the tree. Everything else only decides whether something is said twice, so every
# helper here degrades to "not recorded" and the caller carries on.

TURN_DIR=$(native_path "${TMPDIR:-/tmp}")/web-design

turn_prepare() {
    mkdir -p "$TURN_DIR" 2>/dev/null || return 1
    [ -w "$TURN_DIR" ]
}

# A token from a payload is never trusted into a path.
state_token() {
    _tok=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')
    [ -n "$_tok" ] || _tok=nosession
    printf '%s' "$_tok"
}

state_file() {
    printf '%s/%s.%s\n' "$TURN_DIR" "$(state_token "$1")" "$2"
}

reported_file() {
    printf '%s/%s.%s.reported\n' "$TURN_DIR" "$(state_token "$1")" "$(state_token "$2")"
}

# True the first time it is asked for a given marker, and records that it was asked. When state
# cannot be written it answers true every time: repeating a digest is a cost, staying silent is
# a gap, and the gap is the worse of the two.
state_claim() {
    turn_prepare || return 0
    [ -f "$1" ] && return 1
    : > "$1" 2>/dev/null
    return 0
}

# The client also submits prompts nobody typed — a background task finishing, a slash command's
# expansion. Those must not start a new request.
turn_is_human_prompt() {
    case $(printf '%s' "$1" | sed -e 's/^[[:space:]]*//') in
        "<task-notification>"*|"<system-reminder>"*|"<local-command-"*) return 1 ;;
        "<command-name>"*|"<command-message>"*|"<bash-input>"*) return 1 ;;
        *) return 0 ;;
    esac
}

# Web files that differ from HEAD, plus untracked ones, as absolute paths. A repository with no
# commits yet has no HEAD to diff against, so everything in its index counts.
turn_candidates() {
    _root=$1
    {
        if git -C "$_root" rev-parse --verify -q HEAD >/dev/null 2>&1; then
            git -C "$_root" diff --name-only HEAD 2>/dev/null
        else
            git -C "$_root" ls-files 2>/dev/null
        fi
        git -C "$_root" ls-files --others --exclude-standard 2>/dev/null
    } | awk -v root="$_root" 'NF && !seen[$0]++ { print root "/" $0 }' | web_filter
}

# `path\tsum` for each existing path on stdin.
turn_sums() {
    while IFS= read -r _p; do
        [ -f "$_p" ] || continue
        printf '%s\t%s\n' "$_p" "$(cksum < "$_p" 2>/dev/null | awk '{ print $1 "-" $2 }')"
    done
}

# Writes the snapshot: the request id first, then `path\tsum` lines.
turn_save() {
    { printf 'request\t%s\n' "$2"; turn_sums; } > "$1.new" 2>/dev/null && mv -f "$1.new" "$1" 2>/dev/null
}

turn_request_id() {
    [ -f "$1" ] || return 1
    awk -F'\t' 'NR == 1 && $1 == "request" { print $2; exit }' "$1"
}

# Paths on stdin whose content differs from the snapshot, or that it never saw.
turn_changed() {
    turn_sums | awk -F'\t' -v snap="$1" '
        BEGIN { while ((getline l < snap) > 0) { split(l, f, "\t"); if (f[1] != "request") SUM[f[1]] = f[2] } }
        !($1 in SUM) || SUM[$1] != $2 { print $1 }
    '
}
