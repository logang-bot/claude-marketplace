# Finding declarations and the span of the body each one opens.
#
# Two strategies, chosen by extension: brace matching for C-family syntax, indentation for
# Python. A declaration whose body cannot be located is skipped rather than guessed at, so
# an expression body (fun total() = a + b) is never measured as an empty one.

function count_char(text, ch,   i, n, c) {
    n = 0
    for (i = 1; i <= length(text); i++) if (substr(text, i, 1) == ch) n++
    return n
}

# A declaration that opens a body. Requires a real declaration keyword or an access
# modifier, so that trailing-lambda calls (Column(...) {, items(...) {) are not mistaken
# for functions.
function decl_name(line,   s) {
    if (line !~ /^[[:space:]]*((public|private|protected|internal|open|final|static|abstract|override|suspend|inline|operator|infix|tailrec|async|export|default)[[:space:]]+)*(fun|func|fn|def|function)[[:space:]]+[A-Za-z0-9_]+[[:space:]]*[<(]/)
        return ""
    if (!match(line, /(^|[[:space:]])(fun|func|fn|def|function)[[:space:]]+[A-Za-z0-9_]+/))
        return ""
    s = substr(line, RSTART, RLENGTH)
    sub(/^[[:space:]]*(fun|func|fn|def|function)[[:space:]]+/, "", s)
    return s
}

# Java / C# / C++ style: modifiers, then a return type, then the name. No keyword to key
# on, so an access modifier or `static` is required to keep the match honest. The name is
# the identifier immediately before the parameter list, which is what the Python original
# captured with a lazy quantifier ERE has no equivalent for.
function typed_name(line,   s, p) {
    if (line !~ /^[[:space:]]*((public|private|protected|internal|static|final|abstract|override|virtual|synchronized|native)[[:space:]]+)+[^;{}]*\([^;]*\)[^;{}]*\{[[:space:]]*$/)
        return ""
    p = index(line, "(")
    if (p == 0) return ""
    s = substr(line, 1, p - 1)
    sub(/[[:space:]]+$/, "", s)
    if (!match(s, /[A-Za-z0-9_]+$/)) return ""
    return substr(s, RSTART, RLENGTH)
}

function declaration_at(line, ext,   name) {
    name = decl_name(line)
    if (name != "") return name
    if (ext in KEYWORD) return ""
    return typed_name(line)
}

# Line holding the { that opens the body, or 0 for an expression body.
function body_start(start,   text, opened, after, brace) {
    text = strip_strings(join_lines(start, DECL_SPAN))
    opened = index(text, "(")
    after = (opened > 0) ? close_of_parens(text, opened) : 0
    brace = (after > 0) ? find_from(text, "{", after) : 0
    return (brace > 0) ? start + count_newlines(text, brace) : 0
}

# Line closing the block that opens at `start`, or 0.
function end_of_block(start,   depth, j, bare) {
    depth = 0
    for (j = start; j <= NL; j++) {
        bare = strip_strings(L[j])
        depth += count_char(bare, "{") - count_char(bare, "}")
        if (depth <= 0 && (j > start || index(bare, "}") > 0)) return j
    }
    return 0
}

function indent_of(line,   s) {
    s = line
    sub(/^[[:space:]]*/, "", s)
    return length(line) - length(s)
}

# Last line of the indented body headed by `start`.
function indent_block_end(start,   header, last, j) {
    header = indent_of(L[start])
    last = start
    for (j = start + 1; j <= NL; j++) {
        if (trim(L[j]) == "") continue
        if (indent_of(L[j]) <= header) return last
        last = j
    }
    return last
}

# Sets SPAN_S and SPAN_E to the inclusive bounds of the body opened at `start`.
function body_span(start, ext,   opened, closed) {
    if (ext in INDENT) {
        SPAN_S = start + 1
        SPAN_E = indent_block_end(start)
        return 1
    }
    opened = body_start(start)
    if (opened == 0) return 0
    closed = end_of_block(opened)
    if (closed == 0) return 0
    SPAN_S = opened + 1
    SPAN_E = closed - 1
    return 1
}

function is_ui_component(start,   i, from, ctx, k) {
    from = start - 4
    if (from < 1) from = 1
    ctx = ""
    for (i = from; i <= start; i++) ctx = ctx L[i] "\n"
    for (k = 1; k <= UI_N; k++) if (index(ctx, UI_MARKERS[k]) > 0) return 1
    return 0
}

# Sets F_NAME, F_LINE, F_BODY, F_PARAMS, F_UI, F_S, F_E for the function declared at
# `start`, or returns 0 when no measurable one is.
function function_at(start, ext,   name) {
    name = declaration_at(L[start], ext)
    if (name == "") return 0
    if (!body_span(start, ext)) return 0
    F_NAME = name
    F_LINE = start
    F_S = SPAN_S
    F_E = SPAN_E
    F_BODY = measure_body(SPAN_S, SPAN_E, ext)
    F_PARAMS = count_parameters(parameter_text(start), ext)
    F_UI = is_ui_component(start)
    return 1
}

# Fills FN_* with one entry per declaration, jumping past each body so helpers nested
# inside another function are not double-counted. UI components are recorded with FN_UI
# set — the size rules skip them, the comment rules do not.
function iter_functions(ext,   i, next_i) {
    FN_N = 0
    if (!(ext in MEASURED)) return
    i = 1
    while (i <= NL) {
        if (function_at(i, ext)) {
            FN_N++
            FN_NAME[FN_N] = F_NAME; FN_LINE[FN_N] = F_LINE; FN_BODY[FN_N] = F_BODY
            FN_PARAMS[FN_N] = F_PARAMS; FN_UI[FN_N] = F_UI
            FN_S[FN_N] = F_S; FN_E[FN_N] = F_E
            next_i = F_E + 1
            i = (next_i > i + 1) ? next_i : i + 1
        } else i++
    }
}
