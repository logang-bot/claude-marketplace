# Line-level text handling shared by the measurements.
#
# Every rule here has to survive punctuation that only looks like syntax: a brace inside a
# string, a // inside a URL, a < that is a comparison rather than a generic.

function init_text(   t, n, i) {
    # Text that is not explanation, so it is never a comment finding.
    n = split("noinspection eslint-disable ts-ignore ts-expect-error prettier-ignore " \
              "pragma noqa pylint: mypy: type: fmt: swiftlint: checkstyle nosonar nolint " \
              "suppress formatter region endregion todo fixme hack xxx license licence " \
              "copyright", t, " ")
    DIRECTIVE_N = n
    for (i = 1; i <= n; i++) DIRECTIVES[i] = t[i]
}

function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
}

function endswith(s, tail,   n) {
    n = length(tail)
    return n <= length(s) && substr(s, length(s) - n + 1) == tail
}

function is_import(line) {
    return line ~ /^[[:space:]]*(import|package|using|#include|from[[:space:]]+[^[:space:]]+[[:space:]]+import)([^A-Za-z0-9_]|$)/
}

function is_comment_line(line) {
    return line ~ /^[[:space:]]*(\/\/|#|\*|\/\*)/
}

# Blank out string-literal contents, keeping every index in place.
function strip_strings(line,   out, i, n, c, quote, escaped, keep) {
    out = ""; quote = ""; escaped = 0
    n = length(line)
    for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (escaped) { escaped = 0; keep = (quote == "") }
        else if (c == "\\") { escaped = 1; keep = (quote == "") }
        else if (quote != "") { if (c == quote) quote = ""; keep = 0 }
        else if (c == "\"" || c == "'") { quote = c; keep = 0 }
        else keep = 1
        out = out (keep ? c : " ")
    }
    return out
}

# Lambda arrows and comparisons whose angle bracket is not generic nesting.
function strip_digraphs(text) {
    gsub(/->/, "", text)
    gsub(/=>/, "", text)
    gsub(/>=/, "", text)
    gsub(/<=/, "", text)
    return text
}

# The markers that actually open a comment in this language, as MARK1 and MARK2.
function marks_for(ext) {
    if (ext in INDENT) { MARK1 = "#"; MARK2 = "" }
    else { MARK1 = "//"; MARK2 = "/*" }
}

# Tool directives, work markers, and licence banners are not explanation.
function is_allowed(comment,   s, i) {
    s = comment
    sub(/^[\/#*!<> \t]+/, "", s)
    s = tolower(s)
    if (s == "") return 1
    for (i = 1; i <= DIRECTIVE_N; i++)
        if (index(s, DIRECTIVES[i]) == 1) return 1
    return 0
}

# The comment opening on this line, whole-line or trailing, or "" if there is none.
function comment_in(line,   bare, a, b, at) {
    bare = strip_strings(line)
    a = index(bare, MARK1)
    b = (MARK2 != "") ? index(bare, MARK2) : 0
    at = 0
    if (a > 0) at = a
    if (b > 0 && (at == 0 || b < at)) at = b
    return (at > 0) ? trim(substr(line, at)) : ""
}

# Sets CO_TEXT to the comment on this line and CO_INSIDE to whether a block comment is
# still open after it.
function comment_on(line, inside) {
    if (inside) {
        CO_TEXT = trim(line)
        CO_INSIDE = (index(line, "*/") == 0)
        return
    }
    CO_TEXT = comment_in(line)
    CO_INSIDE = (index(CO_TEXT, "/*") == 1 && index(CO_TEXT, "*/") == 0)
}
