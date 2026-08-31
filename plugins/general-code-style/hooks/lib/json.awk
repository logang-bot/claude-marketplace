# Extracts one scalar from a hook payload, addressed by dotted path.
#
#   awk -f json.awk -v key=tool_input.file_path < payload.json
#
# Exits 0 having printed the value, or 1 when the key is absent or the payload will not
# parse — every caller treats that as "no value" rather than as an error.
#
# The unescaping is a left-to-right scan rather than a series of gsubs on purpose. A
# Windows path arrives as "C:\\new\\file", whose raw text contains the two characters \ and
# n next to each other; any gsub that rewrites \n first would put a newline in the middle
# of a directory name.

function unescape(s,   out, i, n, c, d) {
    if (index(s, "\\") == 0) return s
    out = ""; n = length(s)
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c != "\\") { out = out c; continue }
        i++
        d = substr(s, i, 1)
        if (d == "n") out = out "\n"
        else if (d == "t") out = out "\t"
        else if (d == "r") out = out "\r"
        else if (d == "b" || d == "f") continue
        else if (d == "u") { out = out "?"; i += 4 }
        else out = out d
    }
    return out
}

function skip_ws() {
    while (P <= SN && substr(S, P, 1) ~ /[ \t\n\r]/) P++
}

# The raw text between the quotes, with P left just past the closing quote.
function scan_string(   start, c) {
    P++
    start = P
    while (P <= SN) {
        c = substr(S, P, 1)
        if (c == "\\") { P += 2; continue }
        if (c == "\"") break
        P++
    }
    c = substr(S, start, P - start)
    P++
    return c
}

function scan_literal(   start, c) {
    start = P
    while (P <= SN) {
        c = substr(S, P, 1)
        if (c == "," || c == "}" || c == "]" || c ~ /[ \t\n\r]/) break
        P++
    }
    return substr(S, start, P - start)
}

function record(prefix, raw) {
    if (prefix == key) { RESULT = unescape(raw); FOUND = 1 }
}

function parse_object(prefix,   c, k) {
    P++
    skip_ws()
    if (substr(S, P, 1) == "}") { P++; return }
    while (P <= SN) {
        skip_ws()
        if (substr(S, P, 1) != "\"") return
        k = unescape(scan_string())
        skip_ws()
        if (substr(S, P, 1) != ":") return
        P++
        parse_value(prefix == "" ? k : prefix "." k)
        skip_ws()
        c = substr(S, P, 1)
        P++
        if (c != ",") return
    }
}

function parse_array(prefix,   c) {
    P++
    skip_ws()
    if (substr(S, P, 1) == "]") { P++; return }
    while (P <= SN) {
        parse_value(prefix "[]")
        skip_ws()
        c = substr(S, P, 1)
        P++
        if (c != ",") return
    }
}

function parse_value(prefix,   c) {
    skip_ws()
    c = substr(S, P, 1)
    if (c == "{") parse_object(prefix)
    else if (c == "[") parse_array(prefix)
    else if (c == "\"") record(prefix, scan_string())
    else record(prefix, scan_literal())
}

{ DOC = DOC $0 "\n" }

END {
    S = DOC
    SN = length(S)
    P = 1
    FOUND = 0
    parse_value("")
    if (FOUND) printf "%s\n", RESULT
    exit FOUND ? 0 : 1
}
