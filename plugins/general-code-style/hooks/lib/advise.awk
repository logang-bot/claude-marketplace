# Turns measurement records into the advisory a hook prints, capped at MAX_WARNINGS.
#
# Call with -v scope="in this file" when every record came from one file, or -v scope=""
# when they came from several and naming one would be wrong.

function add_finding(text) {
    FOUND_N++
    FOUND[FOUND_N] = text
}

function note_text(   i, out) {
    out = $4
    for (i = 5; i <= NF; i++) out = out "\t" $i
    return out
}

BEGIN {
    init_limits()
    FS = "\t"
    FOUND_N = 0
}

$1 == "FILE" && $3 + 0 > FILE_LIMIT { add_finding(file_warning($2, $3)) }
$1 == "LONG" { add_finding(length_warning($2, $3, $4, $5)) }
$1 == "WIDE" { add_finding(parameter_warning($2, $3, $4, $5)) }
$1 == "NOTE" { add_finding(comment_warning($2, $3, note_text())) }

END {
    for (i = 1; i <= FOUND_N && i <= MAX_WARNINGS; i++) print FOUND[i]
    if (FOUND_N > MAX_WARNINGS) print more_findings(FOUND_N - MAX_WARNINGS, scope)
}
