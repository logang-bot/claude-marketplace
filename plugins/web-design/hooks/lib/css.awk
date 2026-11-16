# CSS declaration scanner. Function library: css_scan() walks a span of TXT and emits one D
# record per declaration, with the selector it sits under and the line it starts on.
#
# One scanner serves four sources, told apart by `src`:
#
#   css      a .css/.scss/.less file, or a <style> block inside markup
#   inline   a style="..." attribute; `base` is the element's tag
#   styled   a styled-components / emotion template literal; `base` is the styled tag
#
# It is a character scan rather than a regex pass because a declaration's boundaries depend on
# context a line cannot see: a `;` inside url(data:...;base64) or a quoted string ends nothing,
# a `{` opens a nested SCSS rule, and a styled-components `${...}` interpolation can hold any of
# them. Spans are scanned in place in TXT, so positions stay absolute and line_at() works.
#
# At-rules that only filter (@media, @supports, @container, @layer) keep the parent selector, so a
# declaration inside @media still reports the selector it styles. Others (@font-face, @keyframes)
# become the selector themselves, which is what lets the linter ignore a font-family inside
# @font-face: that names a font, it does not use one.

function css_scan(from, to, base, src,   i, c, n, buf, bstart, sp, q, par, sel, e, sels, blks) {
    sp = 0; buf = ""; bstart = 0; q = ""; par = 0
    sels[0] = base
    blks[0] = ++BLOCK
    i = from
    while (i <= to) {
        c = substr(TXT, i, 1)
        if (q != "") {
            buf = buf c
            if (c == "\\") { buf = buf substr(TXT, i + 1, 1); i += 2; continue }
            if (c == q) q = ""
            i++
            continue
        }
        n = substr(TXT, i + 1, 1)
        if (c == "/" && n == "*") {
            e = index(substr(TXT, i + 2, to - i), "*/")
            if (e == 0) break
            i += e + 3
            continue
        }
        if (c == "/" && n == "/" && par == 0 && css_line_comment(i, from)) {
            while (i <= to && substr(TXT, i, 1) != "\n") i++
            continue
        }
        if (c == "$" && n == "{") {
            e = match_close(i + 1, "{", "}", to)
            if (e == 0) break
            if (bstart == 0) bstart = i
            buf = buf "var(--interp)"
            i = e + 1
            continue
        }
        if (c == "\"" || c == "'") {
            q = c
            if (bstart == 0) bstart = i
            buf = buf c
            i++
            continue
        }
        if (c == "(") par++
        else if (c == ")" && par > 0) par--
        if (par == 0 && c == "{") {
            sel = str_trim(buf)
            sp++
            sels[sp] = css_join(sels[sp - 1], sel)
            blks[sp] = ++BLOCK
            buf = ""; bstart = 0; i++
            continue
        }
        if (par == 0 && (c == ";" || c == "}")) {
            css_decl(buf, bstart, sels[sp], blks[sp], src)
            buf = ""; bstart = 0
            if (c == "}" && sp > 0) sp--
            i++
            continue
        }
        if (bstart == 0 && c !~ /[ \t\r\n]/) bstart = i
        buf = buf c
        i++
    }
    css_decl(buf, bstart, sels[sp], blks[sp], src)
}

# A `//` starts a comment only at the start of a line or after whitespace; `https://` does not.
function css_line_comment(i, from,   p) {
    if (i == from) return 1
    p = substr(TXT, i - 1, 1)
    return p ~ /[ \t\r\n;{}]/
}

function css_join(parent, sel,   out, k) {
    if (sel ~ /^@(media|supports|container|layer|include)/) return parent
    if (parent == "" || sel ~ /^@/) return sel
    if (index(sel, "&") == 0) return parent " " sel
    out = ""
    while ((k = index(sel, "&")) > 0) {
        out = out substr(sel, 1, k - 1) parent
        sel = substr(sel, k + 1)
    }
    return out sel
}

function css_decl(buf, start, sel, blk, src,   b, k, prop, val) {
    b = str_trim(buf)
    if (b == "" || start == 0) return
    k = index(b, ":")
    if (k == 0) return
    prop = str_trim(substr(b, 1, k - 1))
    val = str_trim(substr(b, k + 1))
    if (prop !~ /^(--[-A-Za-z0-9_]+|-?[A-Za-z][-A-Za-z0-9]*|[$@][-A-Za-z0-9_]+)$/) return
    if (prop !~ /^--/) prop = tolower(prop)
    sub(/[ \t]*!important$/, "", val)
    if (val == "") return
    emit_decl(line_at(start), blk, sel, prop, val, src)
}
