# CSS-in-JS extraction. Function library.
#
#   jsx_style_object   style={{ fontWeight: 300, color: '#000' }}  ->  D records, src=jsx
#   styled_literals    styled.button`...`, css`...`, createGlobalStyle`...`, keyframes`...`
#                      ->  the template body goes through css_scan, src=styled
#
# Only literal values are reported. `fontWeight: weight` names a variable whose value is not
# in the file, and guessing at it would turn a lint into noise. A bare number on a length
# property gets `px`, as React does; lineHeight and fontWeight stay unitless, as React leaves
# them.

function jsx_style_object(vpos, raw, tag,   off, ob, cb, i, c, depth, q, segstart, blk) {
    if (raw !~ /^\{[ \t\r\n]*\{/) return
    off = index(substr(raw, 2), "{") + 1
    ob = vpos + off - 1
    cb = match_close(ob, "{", "}", vpos + length(raw) - 1)
    if (cb == 0) return
    blk = ++BLOCK
    depth = 0; q = ""
    segstart = ob + 1
    for (i = ob + 1; i < cb; i++) {
        c = substr(TXT, i, 1)
        if (q != "") {
            if (c == "\\") { i++; continue }
            if (c == q) q = ""
            continue
        }
        if (c == "\"" || c == "'" || c == "`") { q = c; continue }
        if (c == "(" || c == "[" || c == "{") depth++
        else if (c == ")" || c == "]" || c == "}") depth--
        else if (c == "," && depth == 0) {
            jsx_pair(segstart, i - 1, tag, blk)
            segstart = i + 1
        }
    }
    jsx_pair(segstart, cb - 1, tag, blk)
}

function jsx_pair(from, to, tag, blk,   s, lead, k, key, val, prop) {
    s = substr(TXT, from, to - from + 1)
    match(s, /^[ \t\r\n]*/)
    lead = RLENGTH
    s = str_trim(s)
    k = index(s, ":")
    if (s == "" || k == 0 || s ~ /^\.\.\./) return
    key = str_trim(substr(s, 1, k - 1))
    val = str_trim(substr(s, k + 1))
    gsub(/["']/, "", key)
    prop = jsx_kebab(key)
    if (val ~ /^"[^"]*"$/ || val ~ /^'[^']*'$/ || val ~ /^`[^`$]*`$/) val = substr(val, 2, length(val) - 2)
    else if (val ~ /^-?[0-9]*\.?[0-9]+$/) {
        if (prop ~ /^(font-size|margin.*|padding.*|gap|row-gap|column-gap|max-width|min-width|width|height|max-height|min-height|border-radius|letter-spacing|top|left|right|bottom)$/ && val != "0")
            val = val "px"
    } else return
    emit_decl(line_at(from + lead), blk, tag, prop, val, "jsx")
}

function jsx_kebab(key,   out, i, c, n) {
    out = ""
    n = length(key)
    for (i = 1; i <= n; i++) {
        c = substr(key, i, 1)
        if (c ~ /[A-Z]/) out = out "-" tolower(c)
        else out = out c
    }
    if (out ~ /^-ms-/ || key ~ /^ms[A-Z]/) sub(/^-?ms-/, "-ms-", out)
    return out
}

# Template literals tagged by a CSS-in-JS helper. The tag decides the selector: styled.button
# styles a button, which is what lets the link and body-text checks recognise it.
function styled_literals(   k, rest, off, abs, endq, m, sel, pre, skip, re) {
    re = "(styled(\\.[A-Za-z0-9]+|\\([^)]*\\))(\\.attrs\\([^`]*\\))?|createGlobalStyle|injectGlobal|keyframes|css)[ \t]*`"
    skip = 0
    for (k = 1; k <= NL; k++) {
        rest = LN[k]
        off = 0
        while (match(rest, re)) {
            m = substr(rest, RSTART, RLENGTH)
            pre = (off + RSTART > 1) ? substr(LN[k], off + RSTART - 1, 1) : ""
            abs = LSTART[k] + off + RSTART + RLENGTH - 2
            rest = substr(rest, RSTART + RLENGTH)
            off += RSTART + RLENGTH - 1
            if (abs < skip || pre ~ /[A-Za-z0-9_$.]/) continue
            endq = styled_close(abs + 1)
            if (endq == 0) return
            skip = endq
            sel = "styled"
            if (m ~ /^styled\.[A-Za-z0-9]+/) { sel = m; sub(/^styled\./, "", sel); sub(/[^A-Za-z0-9].*$/, "", sel); sel = tolower(sel) }
            else if (m ~ /^(createGlobalStyle|injectGlobal)/) sel = ""
            else if (m ~ /^keyframes/) sel = "@keyframes"
            css_scan(abs + 1, endq - 1, sel, "styled")
        }
    }
}

# The backtick that closes a template literal opened just before `pos`, skipping ${...}.
function styled_close(pos,   i, n, c, e) {
    n = length(TXT)
    for (i = pos; i <= n; i++) {
        c = substr(TXT, i, 1)
        if (c == "\\") { i++; continue }
        if (c == "$" && substr(TXT, i + 1, 1) == "{") {
            e = match_close(i + 1, "{", "}", n)
            if (e == 0) return 0
            i = e
            continue
        }
        if (c == "`") return i
    }
    return 0
}
