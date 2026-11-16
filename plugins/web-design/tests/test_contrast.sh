#!/bin/sh
# Fixtures for color.awk: parsing every colour syntax the linter meets, and WCAG contrast ratios
# checked against published reference values.
#
# Contrast is the one finding that reports a number, so the number has to be right: a check that
# says 4.6:1 for a pair that is really 4.4:1 would wave through exactly the grey-on-white text the
# rule exists to stop.
#
# Run: sh plugins/web-design/tests/test_contrast.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
LIB=$HERE/../hooks/lib
# The hooks get this from engine.sh; this suite calls awk directly, so it pins it itself.
unset LC_ALL
LC_NUMERIC=C
export LC_NUMERIC
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-contrast.$$
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

cat > "$WORK/probe.awk" <<'EOF'
BEGIN {
    if (op == "ratio") printf "%.2f\n", color_contrast(fg, bg)
    else if (op == "parse") { if (color_parse(fg)) printf "%d,%d,%d,%.2f\n", CR + 0.5, CG + 0.5, CB + 0.5, CA; else print "none" }
    else if (op == "first") print color_first(fg)
}
EOF

ratio() { awk -f "$LIB/common.awk" -f "$LIB/color.awk" -f "$WORK/probe.awk" -v op=ratio -v fg="$1" -v bg="$2"; }
parse() { awk -f "$LIB/common.awk" -f "$LIB/color.awk" -f "$WORK/probe.awk" -v op=parse -v fg="$1"; }
first() { awk -f "$LIB/common.awk" -f "$LIB/color.awk" -f "$WORK/probe.awk" -v op=first -v fg="$1"; }

# --- reference ratios (WebAIM) -----------------------------------------------

check "black on white" "$(ratio '#000' '#fff')" "21.00"
check "white on white" "$(ratio '#ffffff' '#ffffff')" "1.00"
check "#777 on white" "$(ratio '#777777' '#ffffff')" "4.48"
check "#767676 on white, the lightest passing grey" "$(ratio '#767676' '#fff')" "4.54"
check "#595959 on white" "$(ratio '#595959' '#fff')" "7.00"
check "Tailwind gray-400 on white" "$(ratio '#9ca3af' '#ffffff')" "2.54"
check "white on #0000ff" "$(ratio '#fff' '#0000ff')" "8.59"
check "order does not matter" "$(ratio '#ffffff' '#777777')" "4.48"

# --- syntaxes ----------------------------------------------------------------

check "#rgb" "$(parse '#f80')" "255,136,0,1.00"
check "#rrggbbaa" "$(parse '#00000080')" "0,0,0,0.50"
check "rgb() with commas" "$(parse 'rgb(10, 20, 30)')" "10,20,30,1.00"
check "rgba() with a leading-dot alpha" "$(parse 'rgba(0,0,0,.25)')" "0,0,0,0.25"
check "space syntax with slash alpha" "$(parse 'rgb(0 0 0 / 40%)')" "0,0,0,0.40"
check "hsl()" "$(parse 'hsl(0, 100%, 50%)')" "255,0,0,1.00"
check "hsl() grey" "$(parse 'hsl(0, 0%, 47%)')" "120,120,120,1.00"
check "a named colour with a known value" "$(parse 'white')" "255,255,255,1.00"
check "an unknown word is not a colour" "$(parse 'inherit')" "none"

# A translucent text colour is composited over its background before measuring.
check "50% black on white composites to mid grey" "$(ratio 'rgba(0,0,0,0.5)' '#ffffff')" "$(ratio 'rgb(127.5, 127.5, 127.5)' '#ffffff')"
check "a translucent background is not judged" "$(ratio '#000' 'rgba(255,255,255,0.5)')" "-1.00"

# --- picking the colour out of a value ---------------------------------------

check "the colour inside a border shorthand" "$(first '1px solid #ccc')" "#ccc"
check "the colour inside a shadow" "$(first '0 4px 8px rgba(0, 0, 0, .1)')" "rgba(0, 0, 0, .1)"
check "a gradient yields nothing" "$(first 'linear-gradient(#fff, #000)')" ""
check "a named colour in a shorthand" "$(first '1px solid white')" "white"

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
