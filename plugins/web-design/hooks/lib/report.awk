# Findings in, readable lines out.
#
#   awk -f report.awk -v limit=8 -v root=<repo root>           hook mode: one line per group
#   awk -f report.awk -v mode=audit -v root=<repo root>        audit mode: grouped by file
#
# Findings of the same rule in the same file collapse into one line listing their lines, so a
# stylesheet with thirty off-scale paddings costs one line of the hook's budget, not thirty, and
# cannot crowd out a contrast failure. Groups are ordered by how much the rule matters to a
# reader — legibility first, spacing last — which is also the order they survive `limit` in.

BEGIN {
    FS = "\t"
    report_rank("COLOR-11 TYPO-08 COLOR-10 TYPO-05 TYPO-10 TYPO-13 UX-04 UX-03 UX-02 ICON-02 ICON-03 TYPO-02 SHADOW-03 COLOR-02 TYPO-09 TYPO-04 COLOR-03 SHADOW-02 RADIUS-04 IMG-12 SPACE-08")
}

$1 == "F" { report_add() }

END {
    if (RG_N == 0) exit
    report_sort()
    if (mode == "audit") report_audit()
    else report_hook()
}

function report_rank(list,   t, n, i) {
    n = split(list, t, " ")
    for (i = 1; i <= n; i++) RANK[t[i]] = i
}

function report_add(   p, g) {
    p = $2
    if (root != "" && index(p, root "/") == 1) p = substr(p, length(root) + 2)
    g = p SUBSEP $4
    if (!(g in RG_COUNT)) {
        RG_N++
        RG_KEY[RG_N] = g; RG_PATH[RG_N] = p; RG_RULE[RG_N] = $4; RG_MSG[RG_N] = $5; RG_FIRST[RG_N] = $3 + 0
    }
    RG_COUNT[g]++
    if (RG_COUNT[g] <= 6) RG_LINES[g] = (RG_LINES[g] == "" ? "" : RG_LINES[g] ", ") $3
    RG_TOTAL++
}

function report_before(a, b,   ra, rb) {
    ra = (RG_RULE[a] in RANK) ? RANK[RG_RULE[a]] : 99
    rb = (RG_RULE[b] in RANK) ? RANK[RG_RULE[b]] : 99
    if (mode == "audit" && RG_PATH[a] != RG_PATH[b]) return RG_PATH[a] < RG_PATH[b]
    if (ra != rb) return ra < rb
    if (RG_PATH[a] != RG_PATH[b]) return RG_PATH[a] < RG_PATH[b]
    return RG_FIRST[a] < RG_FIRST[b]
}

function report_sort(   i, j, t) {
    for (i = 1; i <= RG_N; i++) ORD[i] = i
    for (i = 2; i <= RG_N; i++) {
        t = ORD[i]
        for (j = i - 1; j >= 1 && report_before(t, ORD[j]); j--) ORD[j + 1] = ORD[j]
        ORD[j + 1] = t
    }
}

function report_line(k,   g, more) {
    g = RG_KEY[k]
    if (RG_COUNT[g] == 1) return RG_PATH[k] ":" RG_FIRST[k] " — " RG_RULE[k] ": " RG_MSG[k]
    more = (RG_COUNT[g] > 6) ? ", …" : ""
    return RG_PATH[k] " — " RG_RULE[k] " ×" RG_COUNT[g] " (lines " RG_LINES[g] more "), e.g. " RG_MSG[k]
}

function report_hook(   i, cap, hidden) {
    cap = (limit + 0 > 0) ? limit + 0 : RG_N
    hidden = 0
    for (i = 1; i <= RG_N; i++) {
        if (i <= cap) print report_line(ORD[i])
        else hidden += RG_COUNT[RG_KEY[ORD[i]]]
    }
    if (hidden > 0) print "(+" hidden " more findings — `/design-audit` lists everything)"
}

function report_audit(   i, k, last, files, cap) {
    last = ""
    files = 0
    cap = (limit + 0 > 0) ? limit + 0 : RG_N
    for (i = 1; i <= RG_N; i++) {
        k = ORD[i]
        if (i > cap) { print ""; print "(" RG_N - cap " more finding group(s) not shown; drop --top to see them all)"; break }
        if (RG_PATH[k] != last) {
            if (last != "") print ""
            print RG_PATH[k]
            last = RG_PATH[k]
            files++
        }
        print "  " RG_RULE[k] (RG_COUNT[RG_KEY[k]] > 1 ? " ×" RG_COUNT[RG_KEY[k]] : "") "  line " RG_LINES[RG_KEY[k]] (RG_COUNT[RG_KEY[k]] > 6 ? ", …" : "") "  " (RG_COUNT[RG_KEY[k]] > 1 ? "e.g. " : "") RG_MSG[k]
    }
    print ""
    print RG_TOTAL " finding(s) in " files " file(s)."
}
