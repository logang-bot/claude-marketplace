# Test-only driver: prints the measurements the rules make, rather than the advisories
# they turn into. Lets a fixture assert on a body length or a parameter count directly.
#
#   -v mode=functions   name, line, body, params, ui_exempt   per declaration
#   -v mode=comments    line, text                            per explanatory comment
#   -v mode=filelines   code lines, imports excluded
#   -v mode=params -v signature=<text>   parameters counted in one signature
#   -v mode=members     name, kind (P|C|M), visibility rank, line   per direct member
#   -v mode=order       name, line, reason                          per ordering finding

BEGIN {
    init_limits()
    init_text()
    marks_for(ext)
    OFS = "\t"
}

{ sub(/\r$/, ""); L[NR] = $0 }

END {
    NL = NR
    if (mode == "params") { print count_parameters(signature, ext); exit 0 }
    if (mode == "filelines") { print measure_file(); exit 0 }
    iter_functions(ext)
    if (mode == "functions") {
        for (k = 1; k <= FN_N; k++)
            print FN_NAME[k], FN_LINE[k], FN_BODY[k], FN_PARAMS[k], FN_UI[k]
        exit 0
    }
    if (mode == "members" || mode == "order") {
        iter_members(path, ext)
        if (mode == "order") {
            for (k = 1; k <= OD_N; k++) print OD_NAME[k], OD_LINE[k], OD_REASON[k]
            exit 0
        }
        for (k = 1; k <= MB_N; k++) print MB_NAME[k], MB_KIND[k], MB_VIS[k], MB_LINE[k]
        exit 0
    }
    if (mode == "sized") {
        for (k = 1; k <= FN_N; k++) if (!FN_UI[k]) print FN_NAME[k]
        exit 0
    }
    comment_findings(ext)
    for (k = 1; k <= CN; k++) print CLINE[k], CTEXT[k]
}
