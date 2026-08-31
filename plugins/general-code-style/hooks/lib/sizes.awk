# Measurements: file length, body length, and parameter count.
#
# Lines live in the global L[1..NL]; spans are 1-based and inclusive at both ends.

function measure_file(   i, n) {
    n = 0
    for (i = 1; i <= NL; i++) if (trim(L[i]) != "" && !is_import(L[i])) n++
    return n
}

# The lines of a declaration, joined the way Python's readlines() would present them, so
# a newline count gives the line a character sits on.
function join_lines(s, count,   i, e, out) {
    e = s + count - 1
    if (e > NL) e = NL
    out = ""
    for (i = s; i <= e; i++) out = out L[i] "\n"
    return out
}

function count_newlines(text, before,   i, n) {
    n = 0
    for (i = 1; i < before; i++) if (substr(text, i, 1) == "\n") n++
    return n
}

function find_from(text, needle, from,   p) {
    if (from > length(text)) return 0
    p = index(substr(text, from), needle)
    return (p == 0) ? 0 : from + p - 1
}

# Position just past the ) that closes the run opened at `opened`, or 0.
function close_of_parens(text, opened,   depth, i, c, n) {
    depth = 0; n = length(text)
    for (i = opened; i <= n; i++) {
        c = substr(text, i, 1)
        if (c == "(") depth++
        else if (c == ")") depth--
        if (depth == 0) return i + 1
    }
    return 0
}

function enclosed_by_parens(text, opened,   depth, i, c, n) {
    depth = 0; n = length(text)
    for (i = opened; i <= n; i++) {
        c = substr(text, i, 1)
        if (c == "(") depth++
        else if (c == ")") depth--
        if (depth == 0) return substr(text, opened + 1, i - opened - 1)
    }
    return ""
}

function declaration_text(start) {
    return strip_strings(join_lines(start, DECL_SPAN))
}

# Text between the declaration's parentheses, which may wrap across lines.
function parameter_text(start,   text, opened) {
    text = declaration_text(start)
    opened = index(text, "(")
    return (opened > 0) ? enclosed_by_parens(text, opened) : ""
}

# Index just past a leading docstring, which documents rather than implements.
function docstring_end(s, e, ext,   i, at, opener, quote) {
    if (!(ext in INDENT)) return s
    at = 0
    for (i = s; i <= e; i++) if (trim(L[i]) != "") { at = i; break }
    if (at == 0) return s
    opener = trim(L[at])
    quote = ""
    if (index(opener, "\"\"\"") == 1) quote = "\"\"\""
    else if (index(opener, "'''") == 1) quote = "'''"
    if (quote == "") return s
    if (opener != quote && endswith(opener, quote)) return at + 1
    for (i = at + 1; i <= e; i++) if (index(L[i], quote) > 0) return i + 1
    return e + 1
}

# Body size in code lines — blanks, comments, and a docstring do not count.
function measure_body(s, e, ext,   i, from, n) {
    from = docstring_end(s, e, ext)
    n = 0
    for (i = from; i <= e; i++) if (trim(L[i]) != "" && !is_comment_line(L[i])) n++
    return n
}

# `<` nests only after an identifier, so a comparison is not read as a generic.
function angle_depth(generics, previous, char) {
    if (char == "<" && previous ~ /[A-Za-z0-9_>]/) return generics + 1
    if (char == ">" && generics) return generics - 1
    return generics
}

# Commas nested in generics, calls, or collection literals do not separate parameters.
function top_level_commas(text,   i, n, c, p, depth, generics, count) {
    depth = 0; generics = 0; count = 0; n = length(text)
    for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        p = (i == 1) ? " " : substr(text, i - 1, 1)
        if (c == "(" || c == "[" || c == "{") depth++
        else if (c == ")" || c == "]" || c == "}") depth--
        if (depth == 0) generics = angle_depth(generics, p, c)
        if (c == "," && depth == 0 && generics == 0) count++
    }
    return count
}

function starts_with_receiver(text,   first, parts) {
    first = text
    sub(/^[[:space:]]+/, "", first)
    split(first, parts, ",")
    first = parts[1]
    split(first, parts, ":")
    first = trim(parts[1])
    return (first == "self" || first == "cls")
}

# Parameters in a signature. A trailing comma is punctuation, not a parameter.
function count_parameters(text, ext,   total) {
    text = strip_digraphs(text)
    sub(/[[:space:]]+$/, "", text)
    sub(/,+$/, "", text)
    if (trim(text) == "") return 0
    total = top_level_commas(text) + 1
    if ((ext in INDENT) && starts_with_receiver(text)) return total - 1
    return total
}
