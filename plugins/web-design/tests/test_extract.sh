#!/bin/sh
# Fixtures for the extractors' record format: the selector, property, value and — above all — the
# line each declaration is reported on. check-batch.sh scopes an Edit's findings by comparing a
# finding's line with the edit's new_string, so a line number that drifts by one silently drops a
# finding the agent should have been told about.
#
# Run: sh plugins/web-design/tests/test_extract.sh

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ENGINE_LIB=$HERE/../hooks/lib
. "$ENGINE_LIB/engine.sh"
FAILURES=0
WORK=${TMPDIR:-/tmp}/web-design-extract.$$
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

# record <file> <property>: "line|selector|value" of the first declaration of that property.
record() {
    extract_records "$WORK/$1" "${3:-0}" | awk -F'\t' -v p="$2" '$1 == "D" && $6 == p { print $3 "|" $5 "|" $7; exit }'
}

cat > "$WORK/a.scss" <<'EOF'
/* header ; { } */
$brand: #4f46e5;
.card {
  padding: 16px;

  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  }
  .title { font-weight: 700 }
}
@media (max-width: 600px) {
  .card { padding: 8px; }
}
a { background: url(data:image/png;base64,AA==); color: $brand; }
EOF
check "a SCSS variable is recorded" "$(record a.scss '$brand')" "2||#4f46e5"
check "a nested & selector joins its parent" "$(record a.scss box-shadow)" "7|.card:hover|0 4px 12px rgba(0, 0, 0, 0.08)"
check "a nested descendant joins with a space" "$(record a.scss font-weight)" "9|.card .title|700"
check "a ; inside url() ends nothing" "$(record a.scss background)" "14|a|url(data:image/png;base64,AA==)"
check "@media keeps the inner selector" \
    "$(extract_records "$WORK/a.scss" 0 | awk -F'\t' '$6 == "padding" && $3 == 12 { print $5 }')" ".card"

cat > "$WORK/b.tsx" <<'EOF'
export function Card() {
  return (
    <div
      className="p-4"
      style={{
        fontSize: 14,
        lineHeight: 1.6,
      }}
    >
      <h2>Title</h2>
    </div>
  );
}
EOF
check "a JSX key on its own line keeps its line" "$(record b.tsx font-size)" "6|div|14px"
check "a unitless JSX value stays unitless" "$(record b.tsx line-height)" "7|div|1.6"

cat > "$WORK/c.html" <<'EOF'
<html>
<body>
<section>
  <p
     style="color: #333;
            text-align: justify">x</p>
</section>
</body>
</html>
EOF
check "an inline style split over lines keeps each line" "$(record c.html text-align)" "6|p|justify"

printf 'const B = styled.button`\n  padding: 12px;\n  ${(p) => p.big && css`\n    padding: 24px;\n  `}\n`;\n' > "$WORK/d.js"
check "a styled template's first declaration" "$(record d.js padding)" "2|button|12px"

if [ "$FAILURES" -eq 0 ]; then echo "PASSED — 0 failures"; exit 0; fi
echo "FAILED — $FAILURES failures"
exit 1
