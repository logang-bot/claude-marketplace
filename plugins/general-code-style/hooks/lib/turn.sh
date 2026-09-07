# Scopes the style hooks to the work of one request, and holds the baseline they measure against.
#
# The hooks report only what a request introduced. That needs two things git alone cannot give:
# a record of what the tree looked like before the work started, and a record of which findings
# were already in it. Both are taken at UserPromptSubmit and read back at the write and at Stop.
#
# ## Why a request rather than a turn
#
# `prompt_id` looks like the turn boundary — the client calls it "a UUID correlating a user
# prompt with all subsequent events until the next prompt" — but a single request spans several
# of them. The agent yields to wait on a background subagent, `Stop` fires, and the notification
# that wakes it arrives as a fresh prompt with a fresh id. Re-snapshotting there would fold that
# subagent's writes into the baseline and they would never be measured at all, so the snapshot is
# retaken only for a prompt a human actually typed.
#
# ## Why size is the change signal
#
# A candidate counts as worked on when its path is absent from the snapshot, or present with a
# different size. `mv` preserves mtime, so a timestamp test would miss a rename; a rename is
# caught because the destination path is new to the snapshot, not because its bytes changed.
#
# ## Format
#
#   request <prompt id>
#   size    <path>  <bytes>
#   find    <path>  <finding key>
#
# The keys come from keys.awk and are what `introduced.awk` counts against. A path with `size`
# lines but no `find` lines fell past TURN_MAX_BASELINE and falls back to its HEAD content.

TURN_DIR=$(native_path "${TMPDIR:-/tmp}")/general-code-style

# Files whose findings are recorded at snapshot time. Beyond this the baseline comes from HEAD,
# which is older but still honest; the cap is here so a pathologically dirty tree cannot spend
# the hook's whole timeout measuring files the request will never touch.
TURN_MAX_BASELINE=120

# A session id is a UUID, but it arrives from a payload, so anything not filename-safe is
# dropped rather than trusted into a path.
turn_snapshot_file() {
    _key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')
    [ -n "$_key" ] || _key=nosession
    printf '%s/%s.snapshot\n' "$TURN_DIR" "$_key"
}

# A hook that cannot keep state cannot tell whose work it is looking at, and reporting anyway
# would issue exactly the false orders this file exists to prevent.
turn_prepare() {
    mkdir -p "$TURN_DIR" 2>/dev/null || return 1
    [ -w "$TURN_DIR" ] || return 1
    return 0
}

# False for the wakes the client submits on the agent's behalf. There is no origin field on the
# payload, so the envelope the client wraps them in is the only signal; an unrecognised shape
# counts as human, which retakes the snapshot and is the safe direction to be wrong in.
turn_is_human_prompt() {
    case $(printf '%s' "$1" | sed -e 's/^[[:space:]]*//') in
        "<task-notification>"*|"<system-reminder>"*|"<local-command-"*) return 1 ;;
        "<command-name>"*|"<command-message>"*|"<bash-input>"*) return 1 ;;
        *) return 0 ;;
    esac
}

# The prompt id the snapshot was taken under — the id of the request, not of the current turn.
turn_request_id() {
    [ -f "$1" ] || return 1
    awk -F'\t' 'NR == 1 && $1 == "request" { print $2; exit }' "$1"
}

# Paths on stdin, `path<TAB>size` out. A file that vanished between git listing it and this read
# is skipped rather than recorded at size zero.
turn_with_sizes() {
    while IFS= read -r _path; do
        [ -n "$_path" ] || continue
        [ -f "$_path" ] || continue
        printf '%s\t%s\n' "$_path" "$(wc -c < "$_path" 2>/dev/null | tr -d ' ')"
    done
}

# `path<TAB>size` on stdin, the paths this request worked on out.
turn_changed() {
    awk -F'\t' -v snap="$1" '
        BEGIN {
            while ((getline line < snap) > 0) {
                n = split(line, f, "\t")
                if (n >= 3 && f[1] == "size") SIZE[f[2]] = f[3]
            }
            close(snap)
        }
        { if (!($1 in SIZE) || SIZE[$1] != $2) print $1 }
    '
}

# Every path that differs from HEAD, by either route git offers, as `path<TAB>size`. Tracked
# changes cover modifications and staged renames; untracked covers new files and the destination
# of a rename done with plain `mv`. Both the snapshot and the comparison read the tree through
# this, so they can never disagree about what was a candidate.
turn_candidates() {
    _cwd=$1
    _root=$2
    {
        git -C "$_cwd" diff --name-only HEAD 2>/dev/null
        git -C "$_cwd" ls-files --others --exclude-standard 2>/dev/null
    } | LC_ALL=C sort -u \
      | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/scope.awk" \
      | while read -r _name; do
            [ -f "$_root/$_name" ] && printf '%s\n' "$_root/$_name"
        done | turn_with_sizes
}

# $1 is the file to read, $2 the path to name it by — they differ when the baseline is a blob
# read out of HEAD, where only the display path carries the extension the measurement needs.
turn_keys_of() {
    measure_records "$1" "$2" \
        | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/keys.awk" -v emit=1
}

# `path<TAB>size` on stdin, written as a snapshot stamped with the request it belongs to.
turn_save() {
    _snap=$1
    _request=$2
    _rows=$(cat)
    {
        printf 'request\t%s\n' "$_request"
        [ -n "$_rows" ] && printf '%s\n' "$_rows" | awk '{ print "size\t" $0 }'
        _seen=0
        printf '%s\n' "$_rows" | while IFS= read -r _row; do
            [ -n "$_row" ] || continue
            _seen=$((_seen + 1))
            [ "$_seen" -le "$TURN_MAX_BASELINE" ] || break
            _path=${_row%%	*}
            turn_keys_of "$_path" "$_path" | awk -v p="$_path" '{ print "find\t" p "\t" $0 }'
        done
    } > "$_snap" 2>/dev/null
}

# The findings a path already had before the request, written to $5. Recorded keys first; a path
# the snapshot never measured falls back to its HEAD content, and one absent from HEAD too is
# new, so the empty file left behind correctly makes every finding in it the request's own.
turn_baseline_into() {
    _snap=$1
    _cwd=$2
    _root=$3
    _path=$4
    _out=$5

    : > "$_out" 2>/dev/null || return 1
    if [ -f "$_snap" ]; then
        awk -F'\t' -v want="$_path" '$1 == "find" && $2 == want { print $3 }' "$_snap" > "$_out"
        [ -s "$_out" ] && return 0
    fi

    case $_path in
        "$_root"/*) _rel=${_path#"$_root"/} ;;
        *) return 0 ;;
    esac
    _tmp=$TURN_DIR/head.$$
    git -C "$_cwd" show "HEAD:$_rel" > "$_tmp" 2>/dev/null || { rm -f "$_tmp"; return 0; }
    turn_keys_of "$_tmp" "$_path" > "$_out"
    rm -f "$_tmp"
    return 0
}

# Target paths on stdin, the records for findings this request introduced out. The baseline is
# resolved per file and thrown away again, so a batch touching one file reads one baseline.
turn_introduced() {
    _snap=$1
    _cwd=$2
    _root=$3
    _base=$TURN_DIR/base.$$
    while IFS= read -r _target; do
        [ -n "$_target" ] || continue
        turn_baseline_into "$_snap" "$_cwd" "$_root" "$_target" "$_base" || continue
        measure_records "$_target" "$_target" \
            | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/keys.awk" \
                  -f "$ENGINE_LIB/introduced.awk" -v base="$_base"
    done
    rm -f "$_base"
}
