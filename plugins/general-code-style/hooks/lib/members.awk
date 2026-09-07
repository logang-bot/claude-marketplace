# Where a member sits inside a type body, rather than how big it is.
#
# Three orderings are measured, each readable off a single declaration line:
#
#   properties first, then constructors, then methods — never a field between two methods
#   properties in visibility order, widest first
#   methods in visibility order, widest first
#
# The call-order rule the skills also state — a helper directly below the method that calls
# it — is deliberately absent. It needs a call graph, and this engine reads lines rather than
# syntax: it cannot tell `this.charge()` from `gateway.charge()`, or a name inside a string
# from a call. A guessed graph would invent findings, and an invented finding costs more
# than a missed one, so that half stays with the model.
#
# Only ORDERED extensions are walked: every check reads a visibility keyword, and a language
# that has none cannot be measured honestly. Members are collected at depth 1 of a type body,
# with depth held by jumping past every block rather than by counting braces — so a nested
# class, an init block, and a Kotlin companion object are stepped over whole.

function opens_block(line,   bare) {
    bare = strip_strings(line)
    return count_char(bare, "{") > count_char(bare, "}")
}

# The line past the block opening at `at`. Falls forward one line when the block cannot be
# closed, so a malformed file costs a rescan rather than an infinite loop.
function skip_block(at,   closed) {
    closed = end_of_block(at)
    if (closed <= at) return at + 1
    return closed + 1
}

# The declaration's leading modifiers — everything before the parameter list or the value,
# so a `private` appearing in a default argument or an initialiser is never read as one.
function modifier_text(line,   s, p) {
    s = strip_strings(line)
    p = index(s, "(")
    if (p > 0) s = substr(s, 1, p - 1)
    p = index(s, "=")
    if (p > 0) s = substr(s, 1, p - 1)
    return s
}

# Widest first: public 0, internal 1, protected 2, private 3. No modifier ranks as public,
# which is what Kotlin, TypeScript, Swift and Scala mean by its absence. Java's package-private
# is the one language where that reads a shade too wide, and it errs toward silence.
function visibility_rank(line,   s) {
    s = modifier_text(line)
    if (s ~ /(^|[^A-Za-z0-9_])(private|fileprivate)([^A-Za-z0-9_]|$)/) return 3
    if (s ~ /(^|[^A-Za-z0-9_])protected([^A-Za-z0-9_]|$)/) return 2
    if (s ~ /(^|[^A-Za-z0-9_])internal([^A-Za-z0-9_]|$)/) return 1
    return 0
}

# The name of the type declared on this line, or "". A type body with no name of its own —
# Kotlin's `companion object {` — answers with a sentinel: it is still a block whose members
# belong to it rather than to its parent, and only the skipping depends on knowing that.
function type_at(line,   s) {
    if (line !~ /^[[:space:]]*((public|private|protected|internal|open|final|abstract|sealed|data|value|inner|companion|static|export|default|partial|annotation|enum)[[:space:]]+)*(class|interface|object|struct|enum|record|trait|protocol)([[:space:]]+[A-Za-z0-9_]+|[[:space:]]*[:{])/)
        return ""
    if (!match(line, /(class|interface|object|struct|enum|record|trait|protocol)[[:space:]]+[A-Za-z0-9_]+/))
        return "-"
    s = substr(line, RSTART, RLENGTH)
    sub(/^[A-Za-z]+[[:space:]]+/, "", s)
    return s
}

# The line holding the { that opens a type body. body_start() cannot be reused: it keys on the
# closing ) of a parameter list, and most type declarations have no parentheses at all. Bails
# on meeting another declaration first, so a body-less class does not claim the next one's brace.
function type_body_open(start,   j, last, bare) {
    last = start + DECL_SPAN - 1
    if (last > NL) last = NL
    for (j = start; j <= last; j++) {
        bare = strip_strings(L[j])
        if (bare ~ /\{[[:space:]]*$/) return j
        if (j > start && trim(bare) ~ /^(class|interface|object|struct|enum|record|trait|protocol|fun|func|val|var|let)([^A-Za-z0-9_]|$)/)
            return 0
    }
    return 0
}


# The last line of a type declaration, whether or not it opens a body. end_of_block() cannot be
# asked directly: it counts braces from the line it is given, so on a Kotlin `data class Foo(`
# whose primary constructor wraps, it returns the very next line and the walk falls into the
# parameter list — reading the constructor properties as members of the enclosing type.
function type_decl_end(start,   opened, closed, text, p, after) {
    opened = type_body_open(start)
    if (opened > 0) {
        closed = end_of_block(opened)
        if (closed > opened) return closed
    }
    text = strip_strings(join_lines(start, DECL_SPAN))
    p = index(text, "(")
    if (p == 0) return start
    after = close_of_parens(text, p)
    if (after == 0) return start
    return start + count_newlines(text, after)
}
# The name of the property declared on this line, or "". Two shapes, and both require
# something explicit to key on — the honesty trick typed_name() uses. A keyword shape covers
# Kotlin, Swift and Scala, where a property with no modifier at all is still recognisable; a
# typed shape covers Java, C#, TypeScript and PHP, where an access modifier is required, so an
# implicitly-scoped field is missed rather than guessed at.
function property_at(line, ext,   s, p) {
    if (type_at(line) != "") return ""
    s = strip_strings(line)
    if (s ~ /^[[:space:]]*(@[A-Za-z0-9_.]+[[:space:]]+)*((public|private|protected|internal|open|final|static|abstract|override|lateinit|const|readonly|weak|unowned|lazy|volatile|transient)[[:space:]]+)*(val|var|let)[[:space:]]+[A-Za-z0-9_]+/) {
        match(s, /(val|var|let)[[:space:]]+[A-Za-z0-9_]+/)
        p = substr(s, RSTART, RLENGTH)
        sub(/^(val|var|let)[[:space:]]+/, "", p)
        return p
    }
    if (index(s, "(") > 0) return ""
    if (s !~ /^[[:space:]]*(public|private|protected|internal)[[:space:]][^;(){}]*[A-Za-z0-9_$]+[[:space:]]*(;|=|:|\{)/)
        return ""
    sub(/[[:space:]]*(;|=|:|\{).*$/, "", s)
    if (!match(s, /[A-Za-z0-9_$]+$/)) return ""
    return substr(s, RSTART, RLENGTH)
}


# A class member declared with no keyword in front of it — the TypeScript shape, which
# decl_name() cannot see and typed_name() is never asked about. Only consulted for
# IMPLICIT_METHOD languages, and only from inside a type body, so `if (x) {` cannot reach it;
# the control-flow names are refused anyway rather than relying on that.
function member_method_at(line, ext,   s, p, name) {
    if (!(ext in IMPLICIT_METHOD)) return ""
    s = strip_strings(line)
    if (s !~ /^[[:space:]]*((public|private|protected|readonly|static|async|abstract|override|get|set)[[:space:]]+)*[A-Za-z0-9_$]+[[:space:]]*(<[^<>]*>)?[[:space:]]*\([^;]*\)[^;{}]*\{[[:space:]]*$/)
        return ""
    p = index(s, "(")
    if (p == 0) return ""
    s = substr(s, 1, p - 1)
    sub(/<[^<>]*>[[:space:]]*$/, "", s)
    sub(/[[:space:]]+$/, "", s)
    if (!match(s, /[A-Za-z0-9_$]+$/)) return ""
    name = substr(s, RSTART, RLENGTH)
    if (name ~ /^(if|for|while|switch|catch|do|else|return|new)$/) return ""
    return name
}
function is_constructor_name(name, typename) {
    if (name == typename) return 1
    return (name == "constructor" || name == "init" || name == "__construct" || name == "__init__")
}

# Whether this declaration exposes `name` rather than shadowing it — the backing-property
# idiom, where a private field is followed by the public member that publishes it. Only the
# initialiser is searched, and only for a whole identifier, so `val b = 2` is not read as a
# reference to a property called `a`.
function exposes_name(line, name,   s, at, off, before, after) {
    s = strip_strings(line)
    at = index(s, "=")
    if (at == 0) return 0
    s = substr(s, at + 1)
    off = 0
    while (1) {
        at = index(substr(s, off + 1), name)
        if (at == 0) return 0
        at += off
        before = (at == 1) ? "" : substr(s, at - 1, 1)
        after = substr(s, at + length(name), 1)
        if (before !~ /[A-Za-z0-9_$]/ && after !~ /[A-Za-z0-9_$]/) return 1
        off = at + length(name) - 1
    }
}

# Fills MB_* with the direct members of the type body spanning `from`..`to`.
function members_of(from, to, ext, typename,   i, line, name, closed) {
    MB_N = 0
    i = from
    while (i <= to) {
        line = L[i]
        if (trim(line) == "" || is_comment_line(line)) { i++; continue }
        if (type_at(line) != "") { i = type_decl_end(i) + 1; continue }
        name = property_at(line, ext)
        if (name != "") {
            MB_N++
            MB_KIND[MB_N] = "P"; MB_NAME[MB_N] = name
            MB_LINE[MB_N] = i; MB_VIS[MB_N] = visibility_rank(line)
            i++
            continue
        }
        name = declaration_at(line, ext)
        if (name == "") name = member_method_at(line, ext)
        if (name != "" && body_span(i, ext)) {
            closed = SPAN_E
            MB_N++
            MB_KIND[MB_N] = is_constructor_name(name, typename) ? "C" : "M"
            MB_NAME[MB_N] = name
            MB_LINE[MB_N] = i; MB_VIS[MB_N] = visibility_rank(line)
            i = (closed >= i) ? closed + 1 : i + 1
            continue
        }
        if (opens_block(line)) { i = skip_block(i); continue }
        i++
    }
}

function add_order(path, name, line, reason) {
    OD_N++
    OD_PATH[OD_N] = path; OD_NAME[OD_N] = name
    OD_LINE[OD_N] = line; OD_REASON[OD_N] = reason
}

# One finding per member at most: a property below the methods is already misplaced, and
# reporting its visibility as well would be two lines about one move.
function check_members(path,   k, first_method, widest_p, widest_m) {
    first_method = 0
    for (k = 1; k <= MB_N; k++)
        if (MB_KIND[k] == "M") { first_method = MB_LINE[k]; break }

    widest_p = -1; widest_m = -1
    for (k = 1; k <= MB_N; k++) {
        if (MB_KIND[k] == "P") {
            if (first_method > 0 && MB_LINE[k] > first_method)
                add_order(path, MB_NAME[k], MB_LINE[k], "property-below-method")
            else if (widest_p > MB_VIS[k] && !backing_pair(k))
                add_order(path, MB_NAME[k], MB_LINE[k], "property-visibility")
            if (MB_VIS[k] > widest_p) widest_p = MB_VIS[k]
        } else if (MB_KIND[k] == "M") {
            if (widest_m > MB_VIS[k])
                add_order(path, MB_NAME[k], MB_LINE[k], "method-visibility")
            if (MB_VIS[k] > widest_m) widest_m = MB_VIS[k]
        }
    }
}

# Whether this property publishes some more-restricted property of the same type. The whole
# declaration is searched, not just its first line — a Kotlin `val uiState = combine(` puts
# the backing fields on the lines below it — and every property above it is considered, not
# only the one directly above: real classes put the format helpers between the two halves.
function backing_pair(cur,   k, span, text) {
    span = (cur < MB_N) ? MB_LINE[cur + 1] - MB_LINE[cur] : DECL_SPAN
    if (span > DECL_SPAN) span = DECL_SPAN
    if (span < 1) span = 1
    text = strip_strings(join_lines(MB_LINE[cur], span))
    for (k = 1; k < cur; k++) {
        if (MB_KIND[k] != "P" || MB_VIS[k] <= MB_VIS[cur]) continue
        if (exposes_name(text, MB_NAME[k])) return 1
    }
    return 0
}

# Fills OD_* with every ordering finding in the file. Types are stepped over whole once
# walked, so the members of a nested type belong to it and are never mixed into its parent.
function iter_members(path, ext,   i, tname, opened, closed) {
    OD_N = 0
    if (!(ext in ORDERED)) return
    i = 1
    while (i <= NL) {
        tname = type_at(L[i])
        if (tname != "") {
            opened = type_body_open(i)
            closed = (opened > 0) ? end_of_block(opened) : 0
            if (closed > opened) {
                members_of(opened + 1, closed - 1, ext, tname)
                check_members(path)
                i = closed + 1
                continue
            }
        }
        i++
    }
}
