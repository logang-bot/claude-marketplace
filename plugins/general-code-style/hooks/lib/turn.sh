# Scopes the Stop hook to the work of one turn.
#
# The hook used to ask git what was new and get the same answer every turn: an untracked file
# stays untracked until someone commits it, so a file the agent had never touched was reported
# on every turn, forever, as though it had just been created. Ordering a fix on that premise is
# how the agent ends up being told to refactor code nobody asked it to touch.
#
# The boundary comes from `prompt_id`, a base field on every payload that the client describes
# as correlating a user prompt with all subsequent events until the next prompt. The snapshot is
# taken at UserPromptSubmit — the moment the turn begins, before the agent has done anything —
# and read at Stop: a candidate counts as worked on when its path is absent from the snapshot,
# or present with a different size. Taking it at Stop instead would leave the first turn of
# every session with no baseline, and the first turn is often the one that creates the files.
#
# Size, not mtime, is the change signal. `mv` preserves mtime, so an mtime test would miss a
# rename — which is precisely the case that prompted this. A rename is caught by the path being
# new rather than by anything about its contents.

TURN_DIR=${TMPDIR:-/tmp}/general-code-style

# A session id is a UUID, but it arrives from a payload, so anything that is not filename-safe
# is dropped rather than trusted into a path.
turn_snapshot_file() {
    _key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')
    [ -n "$_key" ] || _key=nosession
    printf '%s/%s.snapshot\n' "$TURN_DIR" "$_key"
}

# A hook that cannot keep state cannot tell whose work it is looking at, and reporting anyway
# would issue exactly the false orders this file exists to prevent. Exit 1 is the
# non-blocking-error slot: the message reaches the user and nothing is prevented.
turn_prepare() {
    mkdir -p "$TURN_DIR" 2>/dev/null || return 1
    [ -w "$TURN_DIR" ] || return 1
    return 0
}

turn_prompt_of() {
    [ -f "$1" ] || return 1
    awk -F'\t' 'NR == 1 && $1 == "prompt" { print $2; exit }' "$1"
}

# Paths on stdin, `path<TAB>size` out. A file that vanished between git listing it and this
# read is skipped rather than recorded at size zero.
turn_with_sizes() {
    while IFS= read -r _path; do
        [ -n "$_path" ] || continue
        [ -f "$_path" ] || continue
        printf '%s\t%s\n' "$_path" "$(wc -c < "$_path" 2>/dev/null | tr -d ' ')"
    done
}

# `path<TAB>size` on stdin, the paths this turn worked on out.
turn_changed() {
    awk -F'\t' -v snap="$1" '
        BEGIN {
            while ((getline line < snap) > 0) {
                n = split(line, f, "\t")
                if (n >= 2 && f[1] != "prompt") SIZE[f[1]] = f[2]
            }
            close(snap)
        }
        { if (!($1 in SIZE) || SIZE[$1] != $2) print $1 }
    '
}

# `path<TAB>size` on stdin, stamped with the prompt this turn ran under.
turn_save() {
    { printf 'prompt\t%s\n' "$2"; cat; } > "$1" 2>/dev/null
}

# Every path that differs from HEAD, by either route git offers, as `path<TAB>size`. Tracked
# changes cover modifications and staged renames; untracked covers new files and the
# destination of a rename done with plain `mv`. The same pair dev-workflow's docs-reminder.sh
# uses. Both hooks read the tree through this, so the snapshot and the comparison can never
# disagree about what was a candidate.
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
