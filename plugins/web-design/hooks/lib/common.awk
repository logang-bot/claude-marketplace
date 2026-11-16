# Helpers shared by the extractors and the linter. Function library only: no rules, no BEGIN
# that prints, because CI loads every .awk file in the plugin together.
#
# Every function name in this plugin's awk is unique across all its modules. awk refuses a
# second definition of a name, and CI's load-together check is what would catch it.

function str_trim(s) {
    sub(/^[ \t\r\n]+/, "", s)
    sub(/[ \t\r\n]+$/, "", s)
    return s
}

# Collapses tabs and newlines so a value can never break the tab-separated record format.
function str_flat(s) {
    gsub(/[\t\r\n]+/, " ", s)
    gsub(/  +/, " ", s)
    return str_trim(s)
}

# Line number of an absolute position in TXT, by binary search over LSTART[1..NL].
function line_at(pos,   lo, hi, mid) {
    lo = 1; hi = NL
    while (lo < hi) {
        mid = int((lo + hi + 1) / 2)
        if (LSTART[mid] <= pos) lo = mid
        else hi = mid - 1
    }
    return lo
}

# A declaration record:  D path line block selector property value source
function emit_decl(line, blk, sel, prop, val, src) {
    printf "D\t%s\t%d\t%d\t%s\t%s\t%s\t%s\n", path, line, blk, str_flat(sel), prop, str_flat(val), src
}

# A markup fact:  M path line kind detail
function emit_fact(line, kind, detail) {
    printf "M\t%s\t%d\t%s\t%s\n", path, line, kind, str_flat(detail)
}

# Position of the character that closes the bracket opened at `pos` in TXT, honouring quotes.
# Returns 0 when it never closes before `limit`.
function match_close(pos, opener, closer, limit,   depth, i, c, q) {
    depth = 0; q = ""
    for (i = pos; i <= limit; i++) {
        c = substr(TXT, i, 1)
        if (q != "") {
            if (c == "\\") { i++; continue }
            if (c == q) q = ""
            continue
        }
        if (c == "\"" || c == "'" || c == "`") { q = c; continue }
        if (c == opener) depth++
        else if (c == closer) { depth--; if (depth == 0) return i }
    }
    return 0
}
