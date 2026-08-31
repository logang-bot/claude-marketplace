# Measures one source file and prints a tab-separated record per finding.
#
# Records rather than sentences, because the hooks and the sweep need the same numbers in
# different shapes. `advise.awk` turns them into advisories; `report.awk` into a sweep.
#
#   FILE <path> <code lines>              always, for a file in SOURCE
#   LONG <path> <name> <line> <body>      a body over FUNCTION_LIMIT
#   WIDE <path> <name> <line> <params>    a signature over PARAM_LIMIT
#   NOTE <path> <line> <text>             an explanatory comment inside a body
#
# Call with -v path=<display path> -v ext=<extension, no dot>.

BEGIN {
    init_limits()
    init_text()
    marks_for(ext)
    OFS = "\t"
}

# A checkout with CRLF endings would otherwise leave a stray \r on every line, which the
# Python original never saw: its text-mode read translated the newlines away.
{ sub(/\r$/, ""); L[NR] = $0 }

END {
    NL = NR
    if (!(ext in SOURCE)) exit 0
    print "FILE", path, measure_file()
    iter_functions(ext)
    for (k = 1; k <= FN_N; k++)
        if (!FN_UI[k] && FN_BODY[k] > FUNCTION_LIMIT)
            print "LONG", path, FN_NAME[k], FN_LINE[k], FN_BODY[k]
    for (k = 1; k <= FN_N; k++)
        if (!FN_UI[k] && FN_PARAMS[k] > PARAM_LIMIT)
            print "WIDE", path, FN_NAME[k], FN_LINE[k], FN_PARAMS[k]
    comment_findings(ext)
    for (k = 1; k <= CN; k++)
        print "NOTE", path, CLINE[k], CTEXT[k]
}
