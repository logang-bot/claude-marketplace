#!/bin/sh
# Fixtures for the CSS rules of the linter: each rule gets a case that must be flagged and a
# case that must pass, because a check that stops firing is as silent as one that never existed.
#
# Fixtures are written at runtime into a scratch directory and run through lint_files, the same
# pipeline the hooks and scripts/audit.sh use. Findings are counted with grep rather than parsed,
# so the suite runs on Windows Git Bash with nothing beyond awk and POSIX utilities.
#
# Run: sh plugins/web-design/tests/test_lint_css.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ENGINE_LIB=$HERE/../hooks/lib
. "$ENGINE_LIB/engine.sh"
. "$ENGINE_LIB/brief.sh"
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-lint-css.$$
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

# Lints stdin as a file named $1 and counts findings of rule $2.
count() {
    cat > "$WORK/$1"
    printf '%s\n' "$WORK/$1" | lint_files "$WORK" | grep -c "	$2	" | tr -d ' '
}

# flags|passes <name> <file> <rule> <content>. The content is an argument, not stdin: a function
# at the end of a pipeline runs in a subshell, and its FAILURES increment would be lost.
flags() { check "$1 is flagged" "$(printf '%s\n' "$4" | count "$2" "$3")" "1"; }
passes() { check "$1 passes" "$(printf '%s\n' "$4" | count "$2" "$3")" "0"; }

# --- typography --------------------------------------------------------------

flags "weight 300" t1.css TYPO-08 'p { font-weight: 300; }'
flags "weight lighter" t2.css TYPO-08 'p { font-weight: lighter; }'
flags "a light font shorthand" t3.css TYPO-08 'p { font: 200 18px/1.6 Inter, sans-serif; }'
passes "weights 400 and 700" t4.css TYPO-08 'p { font-weight: 400; } h1 { font-weight: 700; }'

flags "14px body text" t5.css TYPO-05 'body { font-size: 14px; }'
flags "1.4rem on a 62.5%% root" t6.css TYPO-05 'html { font-size: 62.5%; } p { font-size: 1.4rem; }'
passes "18px body and small captions" t7.css TYPO-05 'body { font-size: 18px; } .caption { font-size: 12px; } p.small { font-size: 13px; }'
passes "1.8rem on a 62.5%% root" t8.css TYPO-05 'html { font-size: 62.5%; } body { font-size: 1.8rem; }'

flags "line-height 1.2 on text" t9.css TYPO-10 'p { line-height: 1.2; }'
passes "1.6 body, 1.1 heading" t10.css TYPO-10 'p { line-height: 1.6; } h1 { line-height: 1.1; }'

flags "a 900px article measure" t11.css TYPO-09 '.article { max-width: 900px; }'
passes "65ch text, wide container" t12.css TYPO-09 'p { max-width: 65ch; } .container { max-width: 1200px; }'

flags "justified text" t13.css TYPO-13 'p { text-align: justify; }'
passes "left-aligned text" t14.css TYPO-13 'p { text-align: left; }'

flags "three families" t15.css TYPO-02 'body { font-family: Inter; } h1 { font-family: "Playfair Display", serif; } .x { font-family: Lato; }'
passes "two families plus code and @font-face" t16.css TYPO-02 'body { font-family: Inter, sans-serif; } h1 { font-family: Merriweather, serif; } code { font-family: "Fira Code"; } @font-face { font-family: Comic; }'

sizes=""
for s in 10 11 12 13 14 15 16 17 18 19 20 21 22; do sizes="$sizes .s$s { font-size: ${s}px; }"; done
flags "13 distinct font sizes" t17.css TYPO-04 "$sizes"

# --- colour ------------------------------------------------------------------

flags "pure black text" c1.css COLOR-10 'p { color: #000; }'
flags "pure black rgb" c2.css COLOR-10 'p { color: rgb(0, 0, 0); }'
passes "dark grey text, black background" c3.css COLOR-10 'p { color: #333; } .x { background: #000; }'

flags "a named border colour" c4.css COLOR-02 '.x { border: 1px solid tomato; }'
passes "exempt keywords" c5.css COLOR-02 '.x { color: currentColor; background: white; border-color: transparent; }'

flags "#999 on white" c6.css COLOR-11 'p { color: #999; background: #fff; }'
flags "#777 on white through custom properties" c7.css COLOR-11 ':root { --t: #777; --b: #ffffff; } p { color: var(--t); background-color: var(--b); }'
passes "#595959 on white" c8.css COLOR-11 'p { color: #595959; background: #fff; }'
flags "#999 on white even at 48px" c9.css COLOR-11 'h1 { color: #999; background: #fff; font-size: 48px; }'
passes "#858585 on white at 48px (3:1)" c10.css COLOR-11 'h1 { color: #858585; background: #fff; font-size: 48px; }'
flags "SCSS variables" c11.scss COLOR-11 '$text: #aaa; $bg: #fff; p { color: $text; background: $bg; }'
passes "a gradient background is not judged" c12.css COLOR-11 'p { color: #999; background: linear-gradient(#fff, #eee); }'

colors=""
for n in 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26; do colors="$colors .c$n { color: #${n}${n}${n}; }"; done
flags "17 distinct colour literals" c13.css COLOR-03 "$colors"

# --- shadows -----------------------------------------------------------------

flags "a dark shadow" s1.css SHADOW-03 '.card { box-shadow: 0 4px 8px rgba(0, 0, 0, 0.6); }'
flags "an opaque black shadow" s2.css SHADOW-03 '.card { box-shadow: 0 4px 8px #000; }'
flags "a shadow with no colour" s3.css SHADOW-03 '.card { box-shadow: 0 4px 8px; }'
passes "light shadows and a coloured glow" s4.css SHADOW-03 '.card { box-shadow: 0 4px 12px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.1); } .glow { box-shadow: 0 0 24px rgba(99,102,241,.6); }'
flags "five distinct shadows" s5.css SHADOW-02 '.a{box-shadow:0 1px 2px rgba(0,0,0,.1)} .b{box-shadow:0 2px 4px rgba(0,0,0,.1)} .c{box-shadow:0 3px 6px rgba(0,0,0,.1)} .d{box-shadow:0 4px 8px rgba(0,0,0,.1)} .e{box-shadow:0 5px 10px rgba(0,0,0,.1)}'

# --- whitespace and UX -------------------------------------------------------

flags "off-scale padding" w1.css SPACE-08 '.x { padding: 10px 20px; }'
passes "on-scale spacing" w2.css SPACE-08 '.x { padding: 16px 24px; margin: 0 auto 1.5rem; gap: 1px; }'

flags "an 800ms transition" u1.css UX-04 '.btn { transition: all 0.8s ease; }'
flags "a 100ms transition" u2.css UX-04 '.x { transition: color 100ms; }'
passes "250ms, 300ms and an infinite loop" u3.css UX-04 '.btn { transition: transform 250ms cubic-bezier(.2, .8, .2, 1), opacity 0.3s; } .spin { animation: spin 1s linear infinite; }'

flags "underline on a non-link" u4.css UX-03 '.note { text-decoration: underline; }'
passes "underline on links and abbr" u5.css UX-03 'a:hover, .nav-link { text-decoration: underline; } abbr { text-decoration: underline dotted; }'

# --- DESIGN.md tokens --------------------------------------------------------

mkdir -p "$WORK/briefed"
cat > "$WORK/briefed/DESIGN.md" <<'EOF'
# Design brief

```tokens
font-families: Inter, "Lora"
spacing-scale: 4 8 16 32 64
```
EOF
printf 'body { font-family: Inter; } h1 { font-family: Lora; } .x { font-family: Poppins; }\n' > "$WORK/briefed/b.css"
out=$(printf '%s\n' "$WORK/briefed/b.css" | lint_files "$WORK/briefed")
check "a family outside the brief is flagged" "$(printf '%s\n' "$out" | grep -c "TYPO-02.*poppins" | tr -d ' ')" "1"
check "families inside the brief pass" "$(printf '%s\n' "$out" | grep -c "TYPO-02.*'inter'\|TYPO-02.*'lora'" | tr -d ' ')" "0"
printf '.x { padding: 24px; } .y { padding: 32px; }\n' > "$WORK/briefed/c.css"
out=$(printf '%s\n' "$WORK/briefed/c.css" | lint_files "$WORK/briefed")
check "the brief's spacing scale replaces the default" "$(printf '%s\n' "$out" | grep -c "SPACE-08.*24px" | tr -d ' ')" "1"
check "a value on the brief's scale passes" "$(printf '%s\n' "$out" | grep -c "SPACE-08.*32px" | tr -d ' ')" "0"

# --- audit script ------------------------------------------------------------

printf 'p { font-weight: 300; }\n' > "$WORK/briefed/d.css"
audit=$(sh "$HERE/../scripts/audit.sh" "$WORK/briefed/d.css" 2>&1)
check "the audit reports the finding" "$(printf '%s\n' "$audit" | grep -c 'TYPO-08' | tr -d ' ')" "1"
sh "$HERE/../scripts/audit.sh" --strict "$WORK/briefed/d.css" >/dev/null 2>&1
check "--strict exits 1 on findings" "$?" "1"

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
