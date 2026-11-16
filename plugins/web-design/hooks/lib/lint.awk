# Lint driver: D and M records in (from any number of files), findings out.
#
#   ... | awk -f common.awk -f color.awk -f crossfile.awk -f lint.awk \
#             -v fonts=<a,b> -v icon=<pack> -v spacing="<n n n>"
#
# Findings, tab separated:   F path line RULE message key
#
# The rule IDs are the PDF's own numbering (TYPO-08 is typography rule 8), so a finding points
# straight at the skill rule it breaks. `key` identifies a finding independent of its line, so a
# finding that moves when lines are inserted above it is still recognised as already reported.
#
# Everything is read before anything is judged: a custom property may be defined after the rule
# that uses it, and contrast needs both colours of a block. `fonts`, `icon` and `spacing` come
# from the project's DESIGN.md when it has one; each is optional.
#
# Every check is advisory. The skill rules are guidelines a personality can bend — a Bold site
# may set a 12px all-caps eyebrow on purpose — so the wording invites a one-line reason to keep
# a deliberate choice instead of demanding the change.

BEGIN { FS = "\t" }

$1 == "D" { lint_store_decl() }
$1 == "M" { NM++; MP[NM] = $2; ML[NM] = $3; MK[NM] = $4; MD[NM] = $5 }

END {
    if (ND + NM == 0) exit
    lint_main()
}

function lint_store_decl(   d) {
    d = ++ND
    DP[d] = $2; DL[d] = $3; DB[d] = $2 SUBSEP $4; DS[d] = $5; DPR[d] = $6; DV[d] = $7; DSRC[d] = $8
    if ($6 ~ /^(--|[$@])/ && (!($6 in VARS) || $5 ~ /:root|^html$/)) VARS[$6] = $7
    if ($6 == "font-size" && tolower($5) ~ /(^|[ ,])html$/ && ($7 == "62.5%" || $7 == "10px")) REMBASE = 10
}

function lint_main(   d, m, sc, n, i) {
    if (REMBASE == "") REMBASE = 16
    n = split(spacing == "" ? "0 2 4 8 12 16 24 32 48 64 80 96 128" : spacing, sc, /[ ,]+/)
    for (i = 1; i <= n; i++) if (sc[i] != "") SCALE[sc[i] + 0] = 1
    SCALE_TEXT = spacing == "" ? "2/4/8/12/16/24/32/48/64/80/96/128" : spacing
    for (d = 1; d <= ND; d++) lint_collect_block(d)
    for (d = 1; d <= ND; d++) lint_decl(d)
    lint_contrast()
    for (m = 1; m <= NM; m++) lint_fact(m)
    crossfile_report()
}

function lint_find(p, line, rule, msg, key) {
    gsub(/\t/, " ", msg)
    printf "F\t%s\t%d\t%s\t%s\t%s\n", p, line, rule, msg, rule "|" p "|" key
}

function lint_dfind(d, rule, msg) {
    lint_find(DP[d], DL[d], rule, msg, DS[d] "|" DPR[d] "|" DV[d])
}

# Expands var(--x), $x and @x from the definitions seen. Returns "" when something cannot be
# resolved, which every caller reads as "not judged".
function lint_resolve(v,   i, inner, k, name, rep) {
    for (i = 0; i < 8; i++) {
        if (match(v, /var\(--[-A-Za-z0-9_]+[^()]*\)/)) {
            inner = substr(v, RSTART + 4, RLENGTH - 5)
            k = index(inner, ",")
            name = str_trim(k ? substr(inner, 1, k - 1) : inner)
            rep = (name in VARS) ? VARS[name] : (k ? str_trim(substr(inner, k + 1)) : "")
            if (rep == "") return ""
            v = substr(v, 1, RSTART - 1) rep substr(v, RSTART + RLENGTH)
            continue
        }
        if (match(v, /(^|[ ,(])[$@][-A-Za-z0-9_]+/)) {
            name = substr(v, RSTART, RLENGTH)
            sub(/^[ ,(]/, "", name)
            if (!(name in VARS)) return ""
            v = substr(v, 1, RSTART + RLENGTH - length(name) - 1) VARS[name] substr(v, RSTART + RLENGTH)
            continue
        }
        break
    }
    return v
}

function lint_collect_block(d,   b, v) {
    b = DB[d]
    v = DPR[d]
    if (v == "color") { BCOLOR[b] = d }
    else if (v == "background-color" || v == "background") { BBG[b] = d }
    else if (v == "font-size") { BFS[b] = lint_px(lint_resolve(DV[d]), 16) }
    else if (v == "font-weight") { BFW[b] = (DV[d] ~ /^bold/) ? 700 : lint_resolve(DV[d]) + 0 }
}

function lint_px(v, fs,   num) {
    v = tolower(str_trim(v))
    if (v ~ /^clamp\(/) { sub(/^clamp\(/, "", v); sub(/,.*$/, "", v); return lint_px(v, fs) }
    if (v ~ /^-?[0-9]*\.?[0-9]+px$/) return v + 0
    if (v ~ /^-?[0-9]*\.?[0-9]+rem$/) return (v + 0) * REMBASE
    if (v ~ /^-?[0-9]*\.?[0-9]+em$/) return (v + 0) * fs
    if (v ~ /^-?[0-9]*\.?[0-9]+pt$/) return (v + 0) * 4 / 3
    if (v ~ /^-?0$/) return 0
    if (v == "xx-small") return 9
    if (v == "x-small") return 10
    if (v == "small") return 13
    if (v == "medium") return 16
    return -1
}

function lint_tagof(part,   last) {
    last = str_trim(part)
    sub(/.*[ >+~]/, "", last)
    sub(/[.:#\[].*$/, "", last)
    return last
}

function lint_bodytext(sel,   l, parts, n, i) {
    l = tolower(sel)
    if (l ~ /small|caption|footnote|legal|meta|fine|note|hint|label|badge|tag|copyright|disclaimer|tiny|eyebrow|overline|code|pre|kbd/) return 0
    n = split(l, parts, ",")
    for (i = 1; i <= n; i++) if (lint_tagof(parts[i]) ~ /^(body|p|li|article|blockquote|dd)$/) return 1
    return 0
}

function lint_textblock(sel,   l, parts, n, i) {
    l = tolower(sel)
    if (l ~ /prose|copy|paragraph|lead|description|article|post-body|blog|text-block|reading/) return 1
    n = split(l, parts, ",")
    for (i = 1; i <= n; i++) if (lint_tagof(parts[i]) ~ /^(p|article|blockquote)$/) return 1
    return 0
}

function lint_linksel(sel,   l) {
    l = tolower(sel)
    if (l == "" || l == "styled") return 1
    return l ~ /(^|[ >+~,(])a([.:#\[ ,)>]|$)|link|(^|[ >+~,])(u|ins|abbr|dfn)([.:#\[ ,]|$)/
}

function lint_decl(d,   p, v, raw) {
    p = DPR[d]; raw = DV[d]
    if (p ~ /^(--|[$@])/) { lint_named(d, raw); return }
    v = lint_resolve(raw)
    if (p == "font-weight") lint_weight(d, v)
    else if (p == "font") lint_font_shorthand(d, v)
    else if (p == "font-size") lint_size(d, v)
    else if (p == "line-height") lint_leading(d, v)
    else if (p == "font-family") crossfile_family(d, v)
    else if (p == "text-align" && v ~ /^justify/) lint_dfind(d, "TYPO-13", "justified text on `" DS[d] "` — use left alignment; justify leaves rivers of uneven spacing")
    else if (p == "max-width") lint_measure(d, v)
    else if (p == "color" || p == "-webkit-text-fill-color") lint_textcolor(d, v)
    else if (p == "box-shadow") lint_shadow(d, v)
    else if (p ~ /^(transition|animation)(-duration)?$/) lint_duration(d, v)
    else if (p ~ /^text-decoration(-line)?$/ && v ~ /underline/ && !lint_linksel(DS[d]))
        lint_dfind(d, "UX-03", "underline on `" DS[d] "`, which is not a link — reserve underlined (and blue) text for links")
    else if (p ~ /^(margin|padding)(-(top|right|bottom|left|inline|block)(-(start|end))?)?$/ || p ~ /^(gap|row-gap|column-gap)$/) lint_spacing(d, v)
    if (p ~ /^(color|background|background-color|border|border-(top|right|bottom|left)(-color)?|border-color|outline|outline-color|fill|stroke|box-shadow|text-shadow|text-decoration-color|caret-color|accent-color)$/) lint_named(d, raw)
    if (DSRC[d] != "tw") crossfile_colors(d, raw)
}

function lint_weight(d, v) {
    if ((v ~ /^[0-9]+$/ && v + 0 < 400) || v == "lighter")
        lint_dfind(d, "TYPO-08", "font-weight " v " on `" DS[d] "` — never go below 400 (regular) for any text")
}

function lint_font_shorthand(d, v,   t, n, i) {
    n = split(v, t, " ")
    for (i = 1; i <= n; i++) {
        if (t[i] ~ /^[1-9]00$/ && t[i] + 0 < 400) { lint_dfind(d, "TYPO-08", "font shorthand weight " t[i] " on `" DS[d] "` — never go below 400 (regular)"); break }
        if (t[i] ~ /[0-9](px|rem|em|%|pt)/) break
    }
    if (match(v, /[0-9.]+(px|rem|em|%|pt)(\/[^ ]+)? +/)) crossfile_family(d, substr(v, RSTART + RLENGTH))
}

function lint_size(d, v,   px) {
    if (v == "") return
    crossfile_size(d, v)
    if (!lint_bodytext(DS[d]) || tolower(DS[d]) ~ /(^|[ ,])(html|:root)$/) return
    px = (v ~ /^[0-9.]+%$/) ? (v + 0) * 0.16 : lint_px(v, 16)
    if (px > 0 && px < 16)
        lint_dfind(d, "TYPO-05", "font-size " DV[d] (DV[d] == px "px" ? "" : " (" px "px)") " on `" DS[d] "` — normal text should be 16–32px; long-form text 20px+")
}

function lint_leading(d, v,   r, fs) {
    if (v == "" || !lint_bodytext(DS[d]) || v == "normal") return
    fs = (DB[d] in BFS && BFS[DB[d]] > 0) ? BFS[DB[d]] : 16
    if (v ~ /^[0-9]*\.?[0-9]+$/) r = v + 0
    else if (v ~ /%$/) r = (v + 0) / 100
    else { r = lint_px(v, fs); if (r <= 0) return; r = r / fs }
    if (r < 1.5 || r > 2)
        lint_dfind(d, "TYPO-10", "line-height " DV[d] " on `" DS[d] "` — normal-sized text reads best between 1.5 and 2")
}

function lint_measure(d, v,   fs, px, over) {
    if (v == "" || !lint_textblock(DS[d])) return
    fs = (DB[d] in BFS && BFS[DB[d]] > 0) ? BFS[DB[d]] : 16
    over = 0
    if (v ~ /^[0-9.]+ch$/) over = (v + 0 > 75)
    else if (v ~ /^[0-9.]+r?em$/) over = (lint_px(v, fs) > 40 * fs)
    else if (v ~ /^[0-9.]+px$/) over = (v + 0 > 40 * fs)
    if (over) lint_dfind(d, "TYPO-09", "max-width " DV[d] " on `" DS[d] "` allows more than ~75 characters per line — try 60–70ch")
}

function lint_textcolor(d, v,   c) {
    c = color_first(v)
    if (c == "" || !color_parse(c)) return
    if (CR + CG + CB == 0 && CA > 0.99)
        lint_dfind(d, "COLOR-10", "pure black text on `" DS[d] "` — lighten it to a very dark grey or a dark shade of the main colour")
}

# A named colour anywhere a colour goes. Black as a text colour is COLOR-10's, not this one's.
function lint_named(d, raw,   v, words, n, i, w) {
    if (DSRC[d] == "tw") return
    v = raw
    gsub(/url\([^)]*\)/, "", v)
    n = split(v, words, /[ ,()\/]+/)
    for (i = 1; i <= n; i++) {
        w = tolower(words[i])
        if (w ~ /^(white|transparent|currentcolor|inherit|initial|unset|none)$/ || !color_is_named(w)) continue
        if (w == "black" && DPR[d] == "color") continue
        lint_dfind(d, "COLOR-02", "CSS named colour `" w "` on `" DS[d] "` — pick a deliberate tone from the palette instead")
        return
    }
}

function lint_shadow(d, v,   parts, n, i, s, c, mx, mn) {
    if (DSRC[d] == "tw" || v == "") return
    crossfile_shadow(d)
    n = lint_split_top(v, parts)
    for (i = 1; i <= n; i++) {
        s = str_trim(parts[i])
        if (s == "none" || s == "") continue
        c = color_first(s)
        if (c == "") { lint_dfind(d, "SHADOW-03", "box-shadow on `" DS[d] "` has no colour, so it uses the text colour at full opacity — give it a light rgba() colour"); return }
        if (!color_parse(c)) continue
        mx = CR; if (CG > mx) mx = CG; if (CB > mx) mx = CB
        mn = CR; if (CG < mn) mn = CG; if (CB < mn) mn = CB
        if (mx - mn <= 40 && CA > 0.25) {
            lint_dfind(d, "SHADOW-03", "box-shadow colour " c " on `" DS[d] "` is too dark — keep neutral shadows light (alpha 0.25 or less); coloured glows are fine")
            return
        }
    }
}

# Splits on commas that are not inside parentheses: cubic-bezier(...) and rgba(...) hold commas.
function lint_split_top(v, parts,   n, i, c, depth, buf) {
    n = 0; depth = 0; buf = ""
    for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c == "(") depth++
        else if (c == ")") depth--
        if (c == "," && depth == 0) { parts[++n] = buf; buf = ""; continue }
        buf = buf c
    }
    parts[++n] = buf
    return n
}

function lint_ms(t) {
    t = tolower(t)
    if (t ~ /^[0-9]*\.?[0-9]+ms$/) return t + 0
    if (t ~ /^[0-9]*\.?[0-9]+s$/) return (t + 0) * 1000
    return -1
}

function lint_duration(d, v,   parts, n, i, toks, m, j, ms, all) {
    if (v == "" || (DPR[d] ~ /^animation/ && v ~ /infinite/)) return
    all = (DPR[d] ~ /-duration$/)
    n = lint_split_top(v, parts)
    for (i = 1; i <= n; i++) {
        m = split(parts[i], toks, " ")
        for (j = 1; j <= m; j++) {
            ms = lint_ms(toks[j])
            if (ms < 0) continue
            if (ms > 0 && (ms < 200 || ms > 500)) {
                lint_dfind(d, "UX-04", DPR[d] " " ms "ms on `" DS[d] "` — purposeful animations run 200–500ms")
                return
            }
            if (!all) break
        }
    }
}

function lint_spacing(d, v,   toks, n, i, t, px, a, bad) {
    if (DSRC[d] == "tw" || v == "") return
    n = split(v, toks, " ")
    bad = ""
    for (i = 1; i <= n; i++) {
        t = toks[i]
        if (t ~ /[0-9]em$/ && t !~ /rem$/) continue
        px = lint_px(t, 16)
        if (px < 0) continue
        a = px < 0 ? -px : px
        if (a <= 1 || (a == int(a) && (a in SCALE))) continue
        bad = bad (bad == "" ? "" : ", ") t
    }
    if (bad != "")
        lint_dfind(d, "SPACE-08", DPR[d] " " DV[d] " on `" DS[d] "` — " bad " off the spacing scale (" SCALE_TEXT ")")
}

# Text against a background set in the same block: same CSS rule, same inline style, same element.
function lint_contrast(   b, fd, bd, fg, bg, ratio, need, fs, fw) {
    for (b in BCOLOR) {
        if (!(b in BBG)) continue
        fd = BCOLOR[b]; bd = BBG[b]
        fg = color_first(lint_resolve(DV[fd]))
        bg = color_first(lint_resolve(DV[bd]))
        if (fg == "" || bg == "") continue
        ratio = color_contrast(fg, bg)
        if (ratio < 0) continue
        fs = (b in BFS) ? BFS[b] : 16
        fw = (b in BFW) ? BFW[b] : 400
        need = (fs >= 24 || (fs >= 18.66 && fw >= 700)) ? 3 : 4.5
        if (ratio < need)
            lint_find(DP[fd], DL[fd], "COLOR-11", sprintf("text %s on %s in `%s` has contrast %.2f:1 — needs at least %s:1", fg, bg, DS[fd], ratio, need), DS[fd] "|" fg "|" bg)
    }
}

function lint_fact(m,   t) {
    if (MK[m] == "cta") {
        t = tolower(MD[m])
        if (t ~ /^(click here|here|click|submit|go|ok|link)$/)
            lint_find(MP[m], ML[m], "UX-02", "button/link text \"" t "\" says nothing — describe the action, e.g. \"Start your free trial\"", t)
    } else if (MK[m] == "rastericon")
        lint_find(MP[m], ML[m], "ICON-03", "icon served as a raster image (" MD[m] ") — use SVG icons or an icon font", MD[m])
    else if (MK[m] == "imgmismatch")
        lint_find(MP[m], ML[m], "IMG-12", "side-by-side images have different dimensions (" MD[m] ") — give them exactly the same size", MD[m])
    else if (MK[m] == "iconpack") crossfile_pack(m)
}
