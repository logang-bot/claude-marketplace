#!/bin/sh
# Fixtures for what the sweep looks at.
#
# `--dirty` exists because the hooks report a file over the line cap rather than ordering a
# split, so an unfixed one stays in the working tree. That makes "uncommitted and over the cap"
# a precise definition of outstanding style debt, and this is the command that answers it —
# before a commit by hand, or as a CI gate with --strict.
#
# The two directions both matter. A --dirty sweep that quietly fell back to the whole tree would
# report debt the user never introduced, and one that reported nothing would be a gate that
# passes everything.
#
# Run: sh plugins/general-code-style/tests/test_sweep_scope.sh

set -u
HERE=$(dirname "$0")
SWEEP=$HERE/../scripts/sweep.sh
WORK=${TMPDIR:-/tmp}/sweep-scope-test.$$
FAILURES=0

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/repo/src" "$WORK/repo/build" "$WORK/plain"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

oversized() {
    printf 'package a.b\n\n'
    _i=0
    while [ "$_i" -lt 300 ]; do
        printf 'val line%s = %s\n' "$_i" "$_i"
        _i=$((_i + 1))
    done
}

git -C "$WORK/repo" init -q .
oversized > "$WORK/repo/src/Dirty.kt"
oversized > "$WORK/repo/build/Generated.kt"
printf 'build/\n' > "$WORK/repo/.gitignore"

report=$(sh "$SWEEP" "$WORK/repo" --dirty)

check "an uncommitted file over the cap is listed" \
    "$(printf '%s' "$report" | grep -c 'Dirty.kt' | tr -d ' ')" "1"
check "a gitignored file is not" \
    "$(printf '%s' "$report" | grep -c 'Generated.kt' | tr -d ' ')" "0"
check "the cap is the same one the hooks use" \
    "$(printf '%s' "$report" | grep -c 'over the 250-line cap' | tr -d ' ')" "1"

sh "$SWEEP" "$WORK/repo" --dirty --strict >/dev/null 2>&1
check "--strict fails while something is over the cap" "$?" "1"

printf 'package a.b\n\nclass Small\n' > "$WORK/repo/src/Dirty.kt"
sh "$SWEEP" "$WORK/repo" --dirty --strict >/dev/null 2>&1
check "and passes once it is not" "$?" "0"

# "Not committed yet" means nothing outside a repository, so the sweep says so rather than
# sweeping everything and calling the result uncommitted.
sh "$SWEEP" "$WORK/plain" --dirty >/dev/null 2>&1
check "--dirty outside a repository is refused" "$?" "2"

# The unscoped sweep is unchanged: it still walks everything git tracks, or the tree itself.
oversized > "$WORK/plain/Loose.kt"
check "a plain sweep still walks a non-repository" \
    "$(sh "$SWEEP" "$WORK/plain" | grep -c 'Loose.kt' | tr -d ' ')" "1"

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
