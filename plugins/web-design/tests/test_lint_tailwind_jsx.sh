#!/bin/sh
# Fixtures for the markup side of the linter: HTML, Vue, JSX/TSX style objects, styled-components,
# Tailwind classes, icon packs, CTA text and images.
#
# Every source is normalized to the same declaration records, so these cases check that a weight
# written as `font-weight: 300`, `fontWeight: 300` or `font-light` is caught the same way, and that
# what must not be read (comments, <script> bodies, Tailwind classes in a non-Tailwind project)
# is not.
#
# Run: sh plugins/web-design/tests/test_lint_tailwind_jsx.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ENGINE_LIB=$HERE/../hooks/lib
. "$ENGINE_LIB/engine.sh"
. "$ENGINE_LIB/brief.sh"
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-lint-markup.$$
mkdir -p "$WORK/plain" "$WORK/tw"
printf '{ "devDependencies": { "tailwindcss": "^3.4.0" } }\n' > "$WORK/tw/package.json"
trap 'rm -rf "$WORK"' EXIT INT TERM

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

# count <project> <file> <rule>: lints stdin written as project/file, counts the rule.
count() {
    cat > "$WORK/$1/$2"
    printf '%s\n' "$WORK/$1/$2" | lint_files "$WORK/$1" | grep -c "	$3	" | tr -d ' '
}

# --- HTML --------------------------------------------------------------------

check "an inline light weight is flagged" "$(printf '<p style="font-weight: 200">Hi</p>\n' | count plain a.html TYPO-08)" "1"
check "a <style> block is read" "$(printf '<style>\np { text-align: justify }\n</style>\n' | count plain b.html TYPO-13)" "1"
check "a commented-out element is ignored" \
    "$(printf '<!-- <p style="font-weight: 100">x</p> -->\n' | count plain c.html TYPO-08)" "0"
check "a <script> body is ignored" \
    "$(printf '<script>var s = "<p style=\\"font-weight:100\\">";</script>\n' | count plain d.html TYPO-08)" "0"
check "vague submit text is flagged" "$(printf '<input type="submit" value="Submit">\n' | count plain e.html UX-02)" "1"
check "vague link text is flagged" "$(printf '<a href="/x">Click <b>here</b></a>\n' | count plain f.html UX-02)" "1"
check "descriptive CTA text passes" "$(printf '<button>Start your free trial</button>\n' | count plain g.html UX-02)" "0"
check "a raster icon is flagged" "$(printf '<img src="/img/icons/cart.png" alt="cart">\n' | count plain h.html ICON-03)" "1"
check "a photo is not a raster icon" "$(printf '<img src="/img/team.jpg" alt="Our team">\n' | count plain i.html ICON-03)" "0"
check "mismatched side-by-side images are flagged" \
    "$(printf '<div><img src="a.jpg" width="400" height="300"><img src="b.jpg" width="400" height="250"></div>\n' | count plain j.html IMG-12)" "1"
check "matching side-by-side images pass" \
    "$(printf '<img src="a.jpg" width="400" height="300"><img src="b.jpg" width="400" height="300">\n' | count plain k.html IMG-12)" "0"
check "two icon packs are flagged" \
    "$(printf '<i class="bi bi-star"></i>\n<i class="fa-solid fa-star"></i>\n' | count plain l.html ICON-02)" "1"
check "one icon pack passes" "$(printf '<i class="bi bi-star"></i><i class="bi bi-heart"></i>\n' | count plain m.html ICON-02)" "0"

# --- Vue ---------------------------------------------------------------------

check "a Vue <style scoped> block is read" \
    "$(printf '<template><p>Hi</p></template>\n<style scoped lang="scss">\n.x { p { font-weight: 300; } }\n</style>\n' | count plain n.vue TYPO-08)" "1"

# --- JSX ---------------------------------------------------------------------

check "a JSX style object is read" \
    "$(printf 'export const A = () => <p style={{ fontWeight: 300, color: "#555" }}>x</p>;\n' | count plain o.jsx TYPO-08)" "1"
check "a JSX number gets px on length props" \
    "$(printf 'export const A = () => <div style={{ padding: 10 }}>x</div>;\n' | count plain p.jsx SPACE-08)" "1"
check "a JSX variable is not judged" \
    "$(printf 'export const A = ({ w }) => <p style={{ fontWeight: w }}>x</p>;\n' | count plain q.jsx TYPO-08)" "0"
check "Link text is a CTA" "$(printf 'export const A = () => <Link to="/x">Click here</Link>;\n' | count plain r.tsx UX-02)" "1"
check "icon imports from two packs are flagged" \
    "$(printf 'import { X } from "lucide-react";\nimport { FaBeer } from "react-icons/fa";\n' | count plain s.tsx ICON-02)" "1"
check "TypeScript generics do not derail the scanner" \
    "$(printf 'const a: Array<string> = [];\nexport const B = () => <p style={{ textAlign: "justify" }}>x</p>;\n' | count plain t.tsx TYPO-13)" "1"

# --- styled-components and emotion -------------------------------------------

check "a styled template is read" \
    "$(printf 'const T = styled.h1`\n  font-weight: 200;\n  color: ${(p) => p.c};\n`;\n' | count plain u.js TYPO-08)" "1"
check "a styled selector is the tag" \
    "$(printf 'const L = styled.span`\n  text-decoration: underline;\n`;\n' | count plain v.js UX-03)" "1"
check "a styled link may underline" \
    "$(printf 'const L = styled.a`\n  text-decoration: underline;\n`;\n' | count plain w.js UX-03)" "0"
check "an emotion css literal is read" "$(printf 'const s = css`\n  transition: all 1s;\n`;\n' | count plain x.ts UX-04)" "1"

# --- Tailwind ----------------------------------------------------------------

check "font-light is flagged in a Tailwind project" \
    "$(printf '<p class="font-light text-lg">Hi</p>\n' | count tw a.html TYPO-08)" "1"
check "font-light is ignored without Tailwind" \
    "$(printf '<p class="font-light text-lg">Hi</p>\n' | count plain y.html TYPO-08)" "0"
check "a variant prefix is stripped" "$(printf '<p class="md:text-justify">Hi</p>\n' | count tw b.html TYPO-13)" "1"
check "text-sm on a paragraph is small body text" "$(printf '<p class="text-sm">Hi</p>\n' | count tw c.html TYPO-05)" "1"
check "gray-400 on white fails contrast" \
    "$(printf 'export const A = () => <p className="text-gray-400 bg-white">x</p>;\n' | count tw d.tsx COLOR-11)" "1"
check "gray-600 on white passes contrast" \
    "$(printf 'export const A = () => <p className="text-gray-600 bg-white">x</p>;\n' | count tw e.tsx COLOR-11)" "0"
check "classes inside clsx() are read" \
    "$(printf 'export const A = ({ on }) => <p className={clsx("leading-tight", on && "x")}>x</p>;\n' | count tw f.tsx TYPO-10)" "1"
check "a slow duration is flagged" "$(printf '<button class="transition duration-1000">Go now</button>\n' | count tw g.html UX-04)" "1"
check "an arbitrary off-scale padding is flagged" "$(printf '<div class="p-[13px]">x</div>\n' | count tw h.html SPACE-08)" "1"
check "standard spacing utilities pass" "$(printf '<div class="p-5 mt-7 gap-3">x</div>\n' | count tw i.html SPACE-08)" "0"
check "underline on a button is flagged" "$(printf '<button class="underline">Save changes</button>\n' | count tw j.html UX-03)" "1"
check "underline on a link passes" "$(printf '<a class="underline" href="/x">Pricing</a>\n' | count tw k.html UX-03)" "0"

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
