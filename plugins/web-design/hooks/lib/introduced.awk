# Keeps the findings an edit actually introduced. Needs common.awk loaded alongside.
#
#   awk -f common.awk -f introduced.awk -v pool=<new_strings file> -v edited=<paths file>
#
# A file written with Write is the agent's own work end to end, so all of it is in scope. A file
# changed with Edit is not: it may have carried a justified paragraph for years, and touching the
# line below that is no reason to be told about it. So for an edited file a finding survives only
# when its line belongs to the edit — the line's text appears in some new_string of the batch, or
# a line of a new_string appears inside it (an edit that rewrote part of a line).
#
# The pool is every new_string in the batch rather than per file. Tying each string to its file
# would mean pairing array indexes through MultiEdit's nested edits[]; the cost of not doing it is
# a finding on an edited line that coincidentally matches text written to another file, which is
# rare and harmless.

BEGIN {
    FS = "\t"
    if (edited != "") { while ((getline IN_LINE < edited) > 0) if (IN_LINE != "") EDITED[IN_LINE] = 1; close(edited) }
    IN_POOL = ""
    IN_N = 0
    if (pool != "") {
        while ((getline IN_LINE < pool) > 0) {
            IN_POOL = IN_POOL IN_LINE "\n"
            IN_LINE = str_trim(IN_LINE)
            if (length(IN_LINE) >= 4) IN_PL[++IN_N] = IN_LINE
        }
        close(pool)
    }
}

$1 == "F" {
    if (!($2 in EDITED) || introduced_line($2, $3 + 0)) print
}

function introduced_line(p, n,   t, i) {
    t = str_trim(introduced_text(p, n))
    if (t == "") return 0
    if (index(IN_POOL, t)) return 1
    for (i = 1; i <= IN_N; i++) if (index(t, IN_PL[i])) return 1
    return 0
}

function introduced_text(p, n,   l, k) {
    if (!((p, 0) in IN_FILE)) {
        IN_FILE[p, 0] = 1
        k = 0
        while ((getline l < p) > 0) IN_FILE[p, ++k] = l
        close(p)
    }
    return ((p, n) in IN_FILE) ? IN_FILE[p, n] : ""
}
