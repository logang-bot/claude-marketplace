#!/bin/sh
# Fixtures for the new-file Stop hook.
#
# The hook is driven end to end against a scratch repository rather than having git stubbed
# out: `git init` alone is enough to exercise the untracked path, which is the one that
# catches a file a shell command created.
#
# Both directions matter — a scan that measured every changed file would nag about
# pre-existing violations on every turn, which is as broken as one that measured nothing.
#
# Run: sh plugins/general-code-style/tests/test_new_file_scan.sh

set -u
HERE=$(dirname "$0")
HOOK=$HERE/../hooks/check-new-files.sh
LIB=$HERE/../hooks/lib
WORK=${TMPDIR:-/tmp}/new-file-scan-test.$$
FAILURES=0

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/repo/src"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

run_hook() {
    printf '%s' "$1" | sh "$HOOK" >/dev/null 2>&1
    printf '%s' "$?"
}

oversized_kotlin() {
    printf 'package a.b\n\n'
    n=0
    while [ "$n" -lt 300 ]; do
        printf 'val line%s = %s\n' "$n" "$n"
        n=$((n + 1))
    done
}

git -C "$WORK/repo" init -q .

# --- nothing new yet ---------------------------------------------------------

check "an empty repository is silent" "$(run_hook "{\"cwd\":\"$WORK/repo\"}")" "0"

# --- a file no Write tool ever touched ---------------------------------------

oversized_kotlin > "$WORK/repo/src/Big.kt"
printf 'a\n%.0s' $(seq 1 400) > "$WORK/repo/notes.md"
: > "$WORK/repo/art.png"

check "an untracked oversized source file is caught" \
    "$(run_hook "{\"cwd\":\"$WORK/repo\"}")" "2"

advisory=$(printf '{"cwd":"%s"}' "$WORK/repo" | sh "$HOOK" 2>&1 >/dev/null)
check "the source file is named" \
    "$(printf '%s' "$advisory" | grep -c 'src/Big.kt' | tr -d ' ')" "1"
check "prose is not measured" \
    "$(printf '%s' "$advisory" | grep -c 'notes.md' | tr -d ' ')" "0"
check "binaries are not measured" \
    "$(printf '%s' "$advisory" | grep -c 'art.png' | tr -d ' ')" "0"
check "the wording says the write already succeeded" \
    "$(printf '%s' "$advisory" | grep -c 'already succeeded' | tr -d ' ')" "1"

# --- the guards that keep it from looping or nagging -------------------------

check "a second stop in the same turn is silent" \
    "$(run_hook "{\"cwd\":\"$WORK/repo\",\"stop_hook_active\":true}")" "0"
check "a malformed payload is silent" "$(run_hook 'not json')" "0"
check "an empty payload is silent" "$(run_hook '')" "0"
check "outside a repository is silent" "$(run_hook '{"cwd":"/usr"}')" "0"

# The whole point of the narrow scope: a dirty tree must not re-warn every turn. Dropping
# --diff-filter=A is the single edit that would turn this hook into a nag.
check "the diff is filtered to additions" \
    "$(grep -c -- '--diff-filter=A' "$HOOK" | tr -d ' ')" "1"
check "untracked respects .gitignore" \
    "$(grep -c -- '--exclude-standard' "$HOOK" | tr -d ' ')" "1"

# --- scope, shared with the sweep --------------------------------------------

kept=$(printf 'src/Big.kt\nnotes.md\nart/icon.png\nsrc/small.py\n\n' \
    | awk -f "$LIB/limits.awk" -f "$LIB/scope.awk" | tr '\n' ' ' | sed 's/ $//')
check "only source files survive the filter" "$kept" "src/Big.kt src/small.py"

# --- findings are capped once over the whole set -----------------------------

n=0
while [ "$n" -lt 8 ]; do
    printf 'package a.b\n\nfun f%s(a: Int, b: Int, c: Int, d: Int) {\n    val x = a\n}\n' \
        "$n" > "$WORK/repo/src/Wide$n.kt"
    n=$((n + 1))
done
lines=$(printf '{"cwd":"%s"}' "$WORK/repo" | sh "$HOOK" 2>&1 >/dev/null | grep -c '^- ')
check "one cap over the whole set, not one per file" "$lines" "6"
check "the overflow line does not claim one file" \
    "$(printf '{"cwd":"%s"}' "$WORK/repo" | sh "$HOOK" 2>&1 >/dev/null \
       | grep -c 'more findings in this file' | tr -d ' ')" "0"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
