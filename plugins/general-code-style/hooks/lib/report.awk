# Renders measurement records as the sweep report: a summary, then the worst files.
#
# Call with -v root=<what was swept> -v base=<prefix to strip> -v top=<files to list>.

function file_index(path,   idx) {
    if (path in IDX) return IDX[path]
    NFILES++
    IDX[path] = NFILES
    PATHS[NFILES] = path
    return NFILES
}

function relative(path) {
    if (base != "" && index(path, base "/") == 1) return substr(path, length(base) + 2)
    return path
}

# Structural problems first, then the worst body, then the widest signature. Each
# component is zero-padded to a fixed width so one string compare ranks the whole tuple,
# and the leading "s" keeps awk from reading an all-digit key as a number.
function severity(i) {
    return sprintf("s%08d%08d%08d%08d", over_by(i), LMAX[i], WMAX[i], NN[i])
}

function over_by(i) {
    return (LINES[i] > FILE_LIMIT) ? LINES[i] - FILE_LIMIT : 0
}

function flagged(i) {
    return (LINES[i] > FILE_LIMIT || LN[i] > 0 || WN[i] > 0 || NN[i] > 0)
}

function describe(i,   out, k) {
    out = ""
    if (LINES[i] > FILE_LIMIT) out = LINES[i] " lines"
    for (k = 1; k <= LN[i]; k++) out = (out == "") ? LDESC[i, k] : out " · " LDESC[i, k]
    for (k = 1; k <= WN[i]; k++) out = (out == "") ? WDESC[i, k] : out " · " WDESC[i, k]
    for (k = 1; k <= NN[i]; k++) out = (out == "") ? NDESC[i, k] : out " · " NDESC[i, k]
    return relative(PATHS[i]) "  ·  " out
}

BEGIN {
    init_limits()
    FS = "\t"
    NFILES = 0
}

$1 == "FILE" { i = file_index($2); LINES[i] = $3 + 0; SCANNED++ }
$1 == "LONG" {
    i = file_index($2); LN[i]++
    LDESC[i, LN[i]] = $3 "() " $5 "-line body at :" $4
    if ($5 + 0 > LMAX[i]) LMAX[i] = $5 + 0
}
$1 == "WIDE" {
    i = file_index($2); WN[i]++
    WDESC[i, WN[i]] = $3 "() " $5 " params at :" $4
    if ($5 + 0 > WMAX[i]) WMAX[i] = $5 + 0
}
$1 == "NOTE" { i = file_index($2); NN[i]++; NDESC[i, NN[i]] = "comment at :" $3 }

END {
    over = 0; longs = 0; wides = 0; notes = 0; found = 0
    for (i = 1; i <= NFILES; i++) {
        if (LINES[i] > FILE_LIMIT) over++
        longs += LN[i]; wides += WN[i]; notes += NN[i]
        if (flagged(i)) { found++; SEV[found] = severity(i); RIDX[found] = i }
    }
    # Severity alone decides the order; files that tie keep the order they were
    # measured in, which is the byte order their paths were sorted into.
    for (a = 2; a <= found; a++) {
        key = SEV[a]; at = RIDX[a]
        for (b = a - 1; b >= 1 && SEV[b] < key; b--) { SEV[b + 1] = SEV[b]; RIDX[b + 1] = RIDX[b] }
        SEV[b + 1] = key; RIDX[b + 1] = at
    }

    print "Swept " SCANNED + 0 " files in " root " · size, parameter, and in-body comment" \
          " rules (naming not evaluated)"
    print ""
    print "  " over " files over the " FILE_LIMIT "-line cap"
    print "  " longs " functions over the " FUNCTION_LIMIT "-line body cap"
    print "  " wides " signatures over " PARAM_LIMIT " parameters"
    print "  " notes " comments explaining code inside a body"

    if (found == 0) { print ""; print "Nothing over the caps."; exit 0 }

    shown = (found < top + 0) ? found : top + 0
    print ""
    print "Worst " shown " of " found " files with findings:"
    print ""
    for (a = 1; a <= shown; a++) print "  " describe(RIDX[a])
    if (found > shown) {
        print ""
        print "  " found - shown " more files with findings — re-run after fixing these."
    }
}
