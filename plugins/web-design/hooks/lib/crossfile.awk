# Checks that need the whole set rather than one declaration. Function library for lint.awk.
#
# Per file:   TYPO-04  too many distinct font sizes      (no type scale in DESIGN.md)
#             RADIUS-04 too many distinct radii          (no radius scale in DESIGN.md)
#             COLOR-03 too many distinct colour literals (no palette)
#             SHADOW-02 too many distinct box-shadows    (no sm/md/lg scale)
# Across the set the linter was given:
#             TYPO-02  more than two font families, or one not declared in DESIGN.md
#             ICON-02  more than one icon pack, or one other than DESIGN.md's
#
# "The set" is whatever the caller passed: the files one batch wrote, the files a request
# changed, or a whole tree from scripts/audit.sh. Each finding lands on the line that tipped
# the count over, so it can be found, and so the Edit-scoping in check-batch.sh can tell whether
# the edit that tipped it is the one being reported on.

function crossfile_size(d, v,   k) {
    if (DSRC[d] == "tw" || v ~ /var\(/) return
    k = DP[d] SUBSEP tolower(v)
    if (k in CF_SIZE_SEEN) return
    CF_SIZE_SEEN[k] = 1
    if (++CF_SIZES[DP[d]] == 13)
        lint_find(DP[d], DL[d], "TYPO-04", "13th distinct font-size in this file (" v ") — pick sizes from a type scale instead of one-off values", "sizes")
}

function crossfile_colors(d, raw,   v, lit, k) {
    if (DPR[d] ~ /^(--|[$@])/) return
    v = tolower(raw)
    while (match(v, /#[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*|(rgba?|hsla?)\([^)]*\)/)) {
        lit = substr(v, RSTART, RLENGTH)
        v = substr(v, RSTART + RLENGTH)
        gsub(/ /, "", lit)
        k = DP[d] SUBSEP lit
        if (k in CF_COLOR_SEEN) continue
        CF_COLOR_SEEN[k] = 1
        if (++CF_COLORS[DP[d]] == 17)
            lint_find(DP[d], DL[d], "COLOR-03", "17th distinct colour literal in this file (" lit ") — define the palette (main colour, greys, tints, shades) as custom properties and reuse them", "colors")
    }
}

function crossfile_radius(d, v,   k) {
    v = tolower(v)
    if (v ~ /^0(px)?$/ || v ~ /%$/) return
    k = DP[d] SUBSEP v
    if (k in CF_RADIUS_SEEN) return
    CF_RADIUS_SEEN[k] = 1
    if (++CF_RADII[DP[d]] == 5)
        lint_find(DP[d], DL[d], "RADIUS-04", "5th distinct border-radius in this file (" v ") — keep a small fixed set of radii", "radii")
}

function crossfile_shadow(d,   v, k) {
    v = tolower(DV[d])
    if (v == "none" || v ~ /^var\([^)]*\)$/) return
    k = DP[d] SUBSEP v
    if (k in CF_SHADOW_SEEN) return
    CF_SHADOW_SEEN[k] = 1
    if (++CF_SHADOWS[DP[d]] == 5)
        lint_find(DP[d], DL[d], "SHADOW-02", "5th distinct box-shadow in this file — keep a small sm/md/lg set and use shadows sparingly", "shadows")
}

function crossfile_family(d, v,   f, k, sel) {
    sel = tolower(DS[d])
    if (sel ~ /@font-face|code|pre|kbd|samp|mono/ || v == "") return
    f = v
    k = index(f, ",")
    if (k) f = substr(f, 1, k - 1)
    gsub(/["']/, "", f)
    f = tolower(str_trim(f))
    if (f == "" || f ~ /var\(|icon|awesome|symbols/) return
    if (f ~ /^(serif|sans-serif|monospace|cursive|fantasy|system-ui|ui-sans-serif|ui-serif|ui-monospace|ui-rounded|-apple-system|blinkmacsystemfont|inherit|initial|unset|revert|emoji|math)$/) return
    if (f in CF_FAMLOC) return
    CF_FAMLOC[f] = d
    CF_FAMORDER[++CF_NFAM] = f
}

function crossfile_pack(m,   p) {
    p = MD[m]
    if (p in CF_PACKLOC) return
    CF_PACKLOC[p] = m
    CF_PACKORDER[++CF_NPACK] = p
}

function crossfile_report(   i, d, m, list, declared, n, names, brief) {
    n = split(tolower(fonts), names, /[ ]*,[ ]*/)
    for (i = 1; i <= n; i++) if (names[i] != "") declared[str_trim(names[i])] = 1
    if (n > 0 && fonts != "") {
        for (i = 1; i <= CF_NFAM; i++) {
            if (CF_FAMORDER[i] in declared) continue
            d = CF_FAMLOC[CF_FAMORDER[i]]
            lint_find(DP[d], DL[d], "TYPO-02", "font family '" CF_FAMORDER[i] "' is not in DESIGN.md (declared: " fonts ")", CF_FAMORDER[i])
        }
    } else if (CF_NFAM > 2) {
        list = CF_FAMORDER[1] ", " CF_FAMORDER[2] ", " CF_FAMORDER[3]
        d = CF_FAMLOC[CF_FAMORDER[3]]
        lint_find(DP[d], DL[d], "TYPO-02", CF_NFAM " font families in use (" list ") — one typeface is fine, two at most", list)
    }
    brief = tolower(str_trim(icon))
    for (i = 1; i <= CF_NPACK; i++) {
        m = CF_PACKLOC[CF_PACKORDER[i]]
        if (brief != "" && index(CF_PACKORDER[i], brief) == 0 && index(brief, CF_PACKORDER[i]) == 0)
            lint_find(MP[m], ML[m], "ICON-02", "icon pack " CF_PACKORDER[i] " is not the one DESIGN.md names (" icon ")", CF_PACKORDER[i])
        else if (brief == "" && i >= 2)
            lint_find(MP[m], ML[m], "ICON-02", "icon pack " CF_PACKORDER[i] " mixed with " CF_PACKORDER[1] " — use exactly one pack", CF_PACKORDER[1] "+" CF_PACKORDER[i])
    }
}
