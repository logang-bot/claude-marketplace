#!/bin/sh
# Measure a whole tree against the general-code-style rules.
#
# Loads the caps and the measurements from hooks/lib/ rather than restating them, so a
# sweep and a post-write advisory can never disagree about a cap.
#
# Reports rules 1-3 and the mechanical half of rule 5 — comments that explain code inside a
# function body. Naming, and whether a doc comment says something its member's name already
# says, need judgement about what a reader would misunderstand: that is the style-reviewer
# agent's job, not a script's.
#
# Usage: sweep.sh [path] [--top N] [--strict]

set -u
ENGINE_LIB=${ENGINE_LIB:-$(dirname "$0")/../hooks/lib}
. "$ENGINE_LIB/engine.sh"
require_tools awk

TARGET=.
TOP=20
STRICT=0
while [ $# -gt 0 ]; do
    case $1 in
        --top) TOP=$2; shift 2 ;;
        --top=*) TOP=${1#--top=}; shift ;;
        --strict) STRICT=1; shift ;;
        -*) printf 'sweep: unknown option: %s\n' "$1" >&2; exit 2 ;;
        *) TARGET=$1; shift ;;
    esac
done

TARGET=$(native_path "$TARGET")
[ -e "$TARGET" ] || { printf 'sweep: no such path: %s\n' "$TARGET" >&2; exit 2; }

# Files git knows about, so .gitignore is respected for free; a plain walk when the target
# is not a repository. The pipeline's status is the last command's, so git failing has to
# be tested on its own rather than trusted to fall through an `&&`.
candidates() {
    if [ -f "$TARGET" ]; then
        printf '%s\n' "$TARGET"
        return
    fi
    tracked=$(git -C "$TARGET" ls-files 2>/dev/null) || tracked=""
    if [ -n "$tracked" ]; then
        printf '%s\n' "$tracked" | awk -v prefix="$TARGET" '{ print prefix "/" $0 }'
        return
    fi
    find "$TARGET" -type f 2>/dev/null
}

# LC_ALL=C so the ordering is by byte, which is what decides ties between files of
# equal severity. A locale-aware sort would rank them differently on another machine.
files=$(candidates \
        | awk -f "$ENGINE_LIB/skip.awk" \
        | awk -f "$ENGINE_LIB/limits.awk" -f "$ENGINE_LIB/scope.awk" \
        | LC_ALL=C sort -u)

base=$TARGET
[ -f "$TARGET" ] && base=$(dirname "$TARGET")

records=$(printf '%s\n' "$files" | while read -r name; do
    [ -n "$name" ] && [ -f "$name" ] || continue
    measure_records "$name" "$name"
done)

report=$(printf '%s\n' "$records" | awk -f "$ENGINE_LIB/limits.awk" \
    -f "$ENGINE_LIB/report.awk" -v root="$TARGET" -v base="$base" -v top="$TOP")
printf '%s\n' "$report"

if [ "$STRICT" -eq 1 ] && ! printf '%s' "$report" | grep -q 'Nothing over the caps.'; then
    exit 1
fi
exit 0
