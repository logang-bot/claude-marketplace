# Markup scanner for HTML, Vue, Svelte, Astro and JSX/TSX. Function library.
#
# One pass over TXT, character by character, because JSX attributes hold braces, braces hold
# strings, and strings hold `>`: a tag's end cannot be found by any regex a POSIX awk offers.
# Each start tag is parsed into MA (attribute values), MAP (where each value starts in TXT) and
# MAQ (its opening quote, or `{` for a JSX expression), then handed to markup_handle().
#
# What it reports:
#
#   inline style=""        -> css_scan, selector = the tag
#   JSX style={{...}}      -> jsx_style_object, selector = the tag
#   class / className      -> icon-pack facts; Tailwind declarations when tailwind=1
#   <style> blocks         -> css_scan (not in JSX files, where <style> is rare and literal)
#   <a>/<button>/<Link>    -> a `cta` fact with the visible text
#   <img>                  -> `rastericon` and `imgmismatch` facts
#   <link href>, <ion-icon>, data-lucide, data-feather -> `iconpack` facts

function markup_scan(   i, n, c, nx, e, nm) {
    n = length(TXT)
    i = 1
    MK_CAP = ""
    MK_RUN = ""
    while (i <= n) {
        c = substr(TXT, i, 1)
        if (c != "<") {
            if (MK_CAP != "") MK_CAPBUF = MK_CAPBUF c
            i++
            continue
        }
        nx = substr(TXT, i + 1, 1)
        if (substr(TXT, i, 4) == "<!--") {
            e = markup_find(i + 4, "-->")
            i = e ? e + 3 : n + 1
            continue
        }
        if (nx == "/") {
            nm = ""
            if (match(substr(TXT, i + 2, 64), /^[A-Za-z][-A-Za-z0-9.:_]*/)) nm = substr(TXT, i + 2, RLENGTH)
            if (MK_CAP != "" && nm == MK_CAP) markup_cta_end()
            e = markup_char(i, ">", n)
            i = e ? e + 1 : n + 1
            continue
        }
        if (nx !~ /[A-Za-z]/) {
            if (MK_CAP != "") MK_CAPBUF = MK_CAPBUF c
            i++
            continue
        }
        i = markup_tag(i, n)
    }
}

# First position of a single character at or after `from`, or 0.
function markup_char(from, ch, n,   i) {
    for (i = from; i <= n; i++) if (substr(TXT, i, 1) == ch) return i
    return 0
}

# First position of a string at or after `from`, or 0. Copies the remainder once, so it is kept
# for the rare long jumps (comments, <style>, <script>), never called per character.
function markup_find(from, s,   k) {
    k = index(substr(TXT, from), s)
    return k ? from + k - 1 : 0
}

function markup_tag(pos, n,   p, name, c, an, q, vs, ve, e, self) {
    p = pos + 1
    if (!match(substr(TXT, p, 64), /^[A-Za-z][-A-Za-z0-9.:_]*/)) return pos + 1
    name = substr(TXT, p, RLENGTH)
    p += RLENGTH
    split("", MA); split("", MAP); split("", MAQ)
    self = 0
    while (p <= n) {
        c = substr(TXT, p, 1)
        if (c ~ /[ \t\r\n]/) { p++; continue }
        if (c == ">") { p++; break }
        if (c == "/" && substr(TXT, p + 1, 1) == ">") { self = 1; p += 2; break }
        if (c == "{") {
            e = match_close(p, "{", "}", n)
            p = e ? e + 1 : n + 1
            continue
        }
        if (!match(substr(TXT, p, 128), /^[^ \t\r\n=>\/{]+/)) { p++; continue }
        an = substr(TXT, p, RLENGTH)
        p += RLENGTH
        while (substr(TXT, p, 1) ~ /[ \t\r\n]/) p++
        if (substr(TXT, p, 1) != "=") { MA[an] = ""; continue }
        p++
        while (substr(TXT, p, 1) ~ /[ \t\r\n]/) p++
        q = substr(TXT, p, 1)
        if (q == "\"" || q == "'") {
            vs = p + 1
            e = markup_char(vs, q, n)
            ve = e ? e - 1 : n
            p = ve + 2
        } else if (q == "{") {
            vs = p
            e = match_close(p, "{", "}", n)
            ve = e ? e : n
            p = ve + 1
        } else {
            match(substr(TXT, p, 256), /^[^ \t\r\n>]+/)
            vs = p
            ve = p + RLENGTH - 1
            p = ve + 1
        }
        MA[an] = substr(TXT, vs, ve - vs + 1)
        MAP[an] = vs
        MAQ[an] = q
    }
    markup_handle(name, pos, self)
    return markup_after(name, p, self, n)
}

function markup_after(name, p, self, n,   lname, e, jsx) {
    lname = tolower(name)
    jsx = (tolower(ext) ~ /^(jsx|tsx|js|ts)$/)
    if (self) return p
    if (lname == "style" && !jsx) {
        e = markup_find(p, "</style")
        if (e == 0) e = n + 1
        css_scan(p, e - 1, "", "css")
        e = markup_char(e, ">", n)
        return e ? e + 1 : n + 1
    }
    if (lname == "script" && !jsx) {
        e = markup_find(p, "</script")
        if (e == 0) return n + 1
        e = markup_char(e, ">", n)
        return e ? e + 1 : n + 1
    }
    if (lname == "a" || lname == "button" || name == "Link" || name == "NavLink") {
        MK_CAP = name
        MK_CAPBUF = ""
        MK_CAPLINE = line_at(p)
    }
    return p
}

function markup_handle(name, pos, self,   lname, line, tag, cls, v) {
    lname = tolower(name)
    line = line_at(pos)
    tag = (name == "Link" || name == "NavLink") ? "a" : lname
    if (("style" in MA) && MAQ["style"] != "") {
        if (MAQ["style"] == "{") jsx_style_object(MAP["style"], MA["style"], tag)
        else if (MA["style"] != "") css_scan(MAP["style"], MAP["style"] + length(MA["style"]) - 1, tag, "inline")
    }
    cls = markup_attr_text("class") " " markup_attr_text("className") " " markup_attr_text(":class") " " markup_attr_text("class:list")
    if (cls ~ /[^ ]/) {
        markup_icon_classes(cls, line)
        if (tailwind == 1) tw_classes(cls, line, tag)
    }
    if (lname == "img") markup_img(line, cls)
    if (lname == "ion-icon") emit_fact(line, "iconpack", "ionicons")
    if ("data-lucide" in MA) emit_fact(line, "iconpack", "lucide")
    if ("data-feather" in MA) emit_fact(line, "iconpack", "feather")
    if (lname == "link" && ("href" in MA)) {
        v = icon_pack_of(tolower(MA["href"]))
        if (v != "") emit_fact(line, "iconpack", v)
    }
    if (lname == "input" && tolower(MA["type"]) ~ /^(submit|button)$/ && MA["value"] != "")
        emit_fact(line, "cta", MA["value"])
    if (lname ~ /^(h[1-6]|p|section|article|header|footer|main|nav)$/) MK_RUN = ""
}

# An attribute's text: a quoted value as-is, a JSX expression reduced to its string literals.
function markup_attr_text(an) {
    if (!(an in MA)) return ""
    if (MAQ[an] == "{" || an ~ /^:/) return markup_strings(MA[an])
    return MA[an]
}

# Every string literal inside a JS expression, joined by spaces, with ${...} parts dropped.
function markup_strings(s,   out, i, n, c, q, buf) {
    out = ""; q = ""; buf = ""
    n = length(s)
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q == "") {
            if (c == "\"" || c == "'" || c == "`") { q = c; buf = "" }
            continue
        }
        if (c == "\\") { i++; continue }
        if (q == "`" && c == "$" && substr(s, i + 1, 1) == "{") {
            while (i <= n && substr(s, i, 1) != "}") i++
            buf = buf " "
            continue
        }
        if (c == q) { out = out " " buf; q = ""; continue }
        buf = buf c
    }
    return out
}

function markup_cta_end(   t) {
    t = tolower(str_flat(MK_CAPBUF))
    MK_CAP = ""
    if (t == "" || index(t, "{") || length(t) > 40) return
    emit_fact(MK_CAPLINE, "cta", t)
}

function markup_img(line, cls,   src, w, h, look) {
    src = tolower(MA["src"])
    look = src " " tolower(cls) " " tolower(MA["alt"])
    if (src ~ /\.(png|jpe?g|gif|webp|bmp)([?#"']|$)/ && look ~ /(^|[^a-z])(icons?|ico)([^a-z]|$)/)
        emit_fact(line, "rastericon", MA["src"])
    w = MA["width"]; h = MA["height"]
    gsub(/[{}"' ]/, "", w); gsub(/[{}"' ]/, "", h)
    if (w !~ /^[0-9]+$/ || h !~ /^[0-9]+$/) return
    if (w + 0 <= 64 && h + 0 <= 64) return
    if (MK_RUN != "" && MK_RUN != w "x" h) emit_fact(line, "imgmismatch", w "x" h " vs " MK_RUN)
    MK_RUN = w "x" h
}

function markup_icon_classes(cls, line,   t, n, i, tok, pack, done) {
    n = split(cls, t, /[ \t\r\n]+/)
    for (i = 1; i <= n; i++) {
        tok = t[i]
        sub(/^.*:/, "", tok)
        pack = ""
        if (tok ~ /^fa-/ || tok ~ /^fa[srbldt]?$/) pack = "fontawesome"
        else if (tok ~ /^bi-/ || tok == "bi") pack = "bootstrap-icons"
        else if (tok ~ /^material-(icons|symbols)/) pack = "material"
        else if (tok ~ /^ri-/) pack = "remixicon"
        else if (tok ~ /^ti-/ || tok == "ti") pack = "tabler"
        else if (tok ~ /^bx[sl]?-/ || tok == "bx") pack = "boxicons"
        else if (tok ~ /^ph-/ || tok == "ph") pack = "phosphor"
        else if (tok ~ /^lucide/) pack = "lucide"
        if (pack == "" || (pack in done)) continue
        done[pack] = 1
        emit_fact(line, "iconpack", pack)
    }
}

# Names the icon pack a string (an import, an href, a CSS @import) refers to, or "".
function icon_pack_of(s) {
    if (s ~ /fortawesome|font-?awesome|react-icons\/fa/) return "fontawesome"
    if (s ~ /bootstrap-icons|react-icons\/bs/) return "bootstrap-icons"
    if (s ~ /material-icons|material-symbols|@mui\/icons-material|material-design-icons|react-icons\/md/) return "material"
    if (s ~ /remixicon|react-icons\/ri/) return "remixicon"
    if (s ~ /@tabler\/icons|tabler-icons|react-icons\/tb/) return "tabler"
    if (s ~ /boxicons|react-icons\/bi/) return "boxicons"
    if (s ~ /phosphor|react-icons\/pi/) return "phosphor"
    if (s ~ /ionicons|react-icons\/io/) return "ionicons"
    if (s ~ /lucide|react-icons\/lu/) return "lucide"
    if (s ~ /heroicons|react-icons\/hi/) return "heroicons"
    if (s ~ /feather|react-icons\/fi/) return "feather"
    if (match(s, /react-icons\/[a-z0-9]+/)) return substr(s, RSTART, RLENGTH)
    return ""
}

# Icon packs pulled in by import, require or @import, one fact per line that names one.
function icon_imports(   k, l, pack) {
    for (k = 1; k <= NL; k++) {
        l = tolower(LN[k])
        if (l !~ /(^|[^a-z])(import|require\(|@import|from[ \t]+['"])/) continue
        pack = icon_pack_of(l)
        if (pack != "") emit_fact(k, "iconpack", pack)
    }
}
