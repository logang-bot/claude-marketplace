#!/bin/sh
# Fixtures for the documentation reminder.
#
# Covers the classification the hook makes once git has answered, and the sample it builds
# from the result. The git call itself is left to the end-to-end check in
# docs/testing-and-ci.md.
#
# Run: sh plugins/dev-workflow/tests/test_docs_reminder.sh

set -u
HERE=$(dirname "$0")
RULES=$HERE/../hooks/lib/doc-rules.awk
FAILURES=0

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

classify() {
    printf '%s\n' "$1" | awk -f "$RULES" | tr '\n' ' ' | sed 's/ $//'
}

sample_of() {
    printf '%s\n' "$1" | awk '
        NR <= 4 { out = (NR == 1) ? $0 : out ", " $0 }
        END { print (NR > 4) ? out " (+" NR - 4 " more)" : out }
    '
}

check "code alone" "$(classify 'src/Main.kt
src/Util.py')" "src/Main.kt src/Util.py"

check "doc by extension" "$(classify 'src/Main.kt
README.md')" "src/Main.kt __DOC__"

check "doc by directory" "$(classify 'src/Main.kt
docs/hooks.adoc')" "src/Main.kt __DOC__"

check "config only" "$(classify 'build.gradle
settings.json')" ""

check "nothing changed" "$(classify '')" ""

check "kotlin is code" "$(classify 'a/B.kt')" "a/B.kt"
check "markdown is not code" "$(classify 'a/B.md')" "__DOC__"
check "anything under docs is a doc" "$(classify 'docs/x.png')" "__DOC__"
check "kotlin is not a doc" "$(classify 'a/B.kt')" "a/B.kt"

check "four or fewer listed" "$(sample_of 'a
b')" "a, b"
check "rest counted" "$(sample_of 'a
b
c
d
e
f')" "a, b, c, d (+2 more)"

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
