#!/bin/sh
# Fixtures for the general-code-style measurements.
#
# Fixtures are written to a scratch directory and measured through probe.awk, which prints
# the numbers the rules produce rather than the sentences they become. Both directions
# matter: a check that flags everything is as broken as one that flags nothing.
#
# Run: sh plugins/general-code-style/tests/test_style_rules.sh

set -u
HERE=$(dirname "$0")
LIB=$HERE/../hooks/lib
WORK=${TMPDIR:-/tmp}/style-rules-test.$$
FAILURES=0

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

probe() {
    awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" -f "$LIB/blocks.awk" \
        -f "$LIB/comments.awk" -f "$HERE/probe.awk" \
        -v mode="$1" -v ext="$2" -v signature="${4:-}" -- "$3"
}

advise() {
    awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" -f "$LIB/blocks.awk" \
        -f "$LIB/comments.awk" -f "$LIB/measure.awk" -v path="$2" -v ext="$1" -- "$3" \
    | awk -f "$LIB/limits.awk" -f "$LIB/findings.awk" -f "$LIB/advise.awk" \
        -v scope="in this file"
}

body_of() {
    n=0
    while [ "$n" -lt 12 ]; do
        printf '        val step%s = %s\n' "$n" "$n"
        n=$((n + 1))
    done
}

# --- fixtures ---------------------------------------------------------------

{
    printf '\nclass Repo {\n    fun wrappedParams(\n        alpha: String,\n'
    printf '        beta: String,\n    ): String {\n'
    body_of
    printf '        return step1.toString()\n    }\n}\n'
} > "$WORK/wrapped.kt"

{
    printf '\nclass Repo {\n    fun first(a: Int) {\n'
    body_of
    printf '    }\n\n    fun second(a: Int) {\n'
    body_of
    printf '    }\n}\n'
} > "$WORK/two.kt"

cat > "$WORK/narrated.kt" <<'KT'

class Repo {
    fun applyTax(order: Order): Money {
        // step one: get the rate
        val rate = rates.of(order)
        val net = order.net * rate   // adds tax
        return net
    }
}
KT

cat > "$WORK/allowed.kt" <<'KT'

/* Copyright 2026 Someone. Licensed under the MIT licence. */
package com.example

/**
 * Applies the Black-Scholes formula, whose correctness is not evident from the code.
 */
class Repo {
    fun applyTax(order: Order): Money {
        // TODO: round half-even
        // noinspection UnusedVariable
        @Suppress("unused")
        val docs = "see https://example.com/tax#rates"
        return docs.length
    }
}
KT

{
    printf '\n@Composable\nfun TaxScreen(\n'
    printf '    a: String, b: String, c: String, d: String, e: String, f: String\n) {\n'
    body_of
    printf '        // this narration is still a finding\n        val extra = 1\n}\n'
} > "$WORK/composable.kt"

cat > "$WORK/brace.kt" <<'KT'

class Repo {
    fun render(a: Int): String {
        val opening = "{"
        return opening + a
    }
}
KT

cat > "$WORK/module.py" <<'PY'

class Repo:
    def apply_tax(self, order, rate, mode):
        """Applies the rate, and this docstring must not count as a body line."""
        step0 = 0
        step1 = 1
        step2 = 2
        step3 = 3
        step4 = 4
        step5 = 5
        step6 = 6
        step7 = 7
        step8 = 8
        step9 = 9
        # narration inside a python body
        return step9

    def small(self, order):
        return order
PY

cat > "$WORK/starargs.py" <<'PY'

def call_it(target):
    args = [1, 2]
    return target(
        *args,
    )
PY

# --- the regression this work started from ----------------------------------

check "wrapped signature is found" "$(probe functions kt "$WORK/wrapped.kt" | wc -l | tr -d ' ')" "1"
check "wrapped body measured" "$(probe functions kt "$WORK/wrapped.kt" | cut -f3)" "13"
check "wrapped params counted" "$(probe functions kt "$WORK/wrapped.kt" | cut -f4)" "2"

# --- every offender, not just the worst -------------------------------------

check "both long functions reported" \
    "$(advise kt Repo.kt "$WORK/two.kt" | wc -l | tr -d ' ')" "2"
check "second one named" \
    "$(advise kt Repo.kt "$WORK/two.kt" | sed -n 2p | grep -c 'second' | tr -d ' ')" "1"

# --- comments ---------------------------------------------------------------

check "whole-line and trailing narration" \
    "$(probe comments kt "$WORK/narrated.kt" | wc -l | tr -d ' ')" "2"
check "whole-line narration line" "$(probe comments kt "$WORK/narrated.kt" | sed -n 1p | cut -f1)" "4"
check "trailing narration line" "$(probe comments kt "$WORK/narrated.kt" | sed -n 2p | cut -f1)" "6"
check "directives, markers, banners, urls" \
    "$(probe comments kt "$WORK/allowed.kt" | wc -l | tr -d ' ')" "0"

# --- the UI component exemption ---------------------------------------------

check "composable is yielded" "$(probe functions kt "$WORK/composable.kt" | wc -l | tr -d ' ')" "1"
check "composable marked exempt" "$(probe functions kt "$WORK/composable.kt" | cut -f5)" "1"
check "size rules skip it" "$(probe sized kt "$WORK/composable.kt" | wc -l | tr -d ' ')" "0"
check "comment rules do not" "$(probe comments kt "$WORK/composable.kt" | wc -l | tr -d ' ')" "1"

# --- punctuation that only looks like syntax --------------------------------

check "a brace in a string does not open a body" \
    "$(probe functions kt "$WORK/brace.kt" | cut -f3)" "2"

# --- python ------------------------------------------------------------------

check "docstring does not count as a body line" \
    "$(probe functions py "$WORK/module.py" | sed -n 1p | cut -f3)" "11"
check "self is not a parameter" \
    "$(probe functions py "$WORK/module.py" | sed -n 1p | cut -f4)" "3"
check "star args do not confuse the counter" \
    "$(probe functions py "$WORK/starargs.py" | cut -f4)" "1"

# --- parameter counting ------------------------------------------------------

check "generic commas do not separate parameters" \
    "$(probe params kt /dev/null 'a: Map<String, Int>, b: Int')" "2"
check "a trailing comma is punctuation" "$(probe params kt /dev/null 'a: Int, b: Int,')" "2"
check "an empty signature has no parameters" "$(probe params kt /dev/null '')" "0"
check "a lambda arrow is not a generic" \
    "$(probe params kt /dev/null 'onClick: () -> Unit, label: String')" "2"

# --- one scope, shared by the hook and the sweep -----------------------------

for ext in kt py lua rb tf md json yaml png jar txt lock; do
    : > "$WORK/scoped.$ext"
    measured=$(awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" \
        -f "$LIB/blocks.awk" -f "$LIB/comments.awk" -f "$LIB/measure.awk" \
        -v path="x.$ext" -v ext="$ext" -- "$WORK/scoped.$ext" | grep -c . | tr -d ' ')
    swept=$(printf 'x.%s\n' "$ext" | awk -f "$LIB/limits.awk" -f "$LIB/scope.awk" \
        | grep -c . | tr -d ' ')
    check "hook and sweep agree on .$ext" "$measured" "$swept"
done

check "an unmeasured language gets no function checks" \
    "$(probe functions rb "$WORK/module.py" | wc -l | tr -d ' ')" "0"

# --- results -----------------------------------------------------------------

if [ "$FAILURES" -eq 0 ]; then
    printf 'PASSED — 0 failures\n'
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
