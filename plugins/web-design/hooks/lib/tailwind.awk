# Tailwind utility classes, mapped to the declarations they stand for. Function library.
#
# Called only when the project uses Tailwind (engine.sh decides), so a plain class named
# `light` or `underline` in a non-Tailwind project is never read as a utility.
#
# Two sources are told apart. Standard utilities (src=tw) already sit on Tailwind's scales, so
# they are exempt from the "too many distinct values" and spacing-scale checks; they still feed
# the checks a scale cannot fix — weight below 400, justified text, pure black, contrast, slow
# transitions. Arbitrary values (src=twa) like p-[13px] or text-[15px] are hand-picked numbers
# and are checked like any CSS.
#
# Colors are known only for the neutral families (slate, gray, zinc, neutral, stone) plus white
# and black: those are what text and backgrounds are mostly made of, and so where contrast fails.
# A brand color class is simply not resolved, which costs a contrast check, never a false one.

function tw_classes(cls, line, tag,   t, n, i, tok, blk) {
    if (!TW_READY) tw_init()
    blk = ++BLOCK
    n = split(cls, t, /[ \t\r\n]+/)
    for (i = 1; i <= n; i++) {
        tok = tw_base(t[i])
        if (tok == "") continue
        sub(/^!/, "", tok)
        sub(/^-/, "", tok)
        tw_one(tok, line, blk, tag)
    }
}

# The utility without its variants: md:hover:text-sm -> text-sm. A colon inside [...] is part
# of an arbitrary value, not a variant separator.
function tw_base(tok,   i, n, c, depth, last) {
    n = length(tok); depth = 0; last = 0
    for (i = 1; i <= n; i++) {
        c = substr(tok, i, 1)
        if (c == "[") depth++
        else if (c == "]") depth--
        else if (c == ":" && depth == 0) last = i
    }
    return substr(tok, last + 1)
}

function tw_one(b, line, blk, tag,   w, c) {
    if (b ~ /^font-(thin|extralight|light)$/) {
        w = (b == "font-thin") ? 100 : (b == "font-extralight") ? 200 : 300
        emit_decl(line, blk, tag, "font-weight", w, "tw")
    } else if (b == "text-justify") emit_decl(line, blk, tag, "text-align", "justify", "tw")
    else if (b == "underline") emit_decl(line, blk, tag, "text-decoration", "underline", "tw")
    else if (b in TW_SIZE) emit_decl(line, blk, tag, "font-size", TW_SIZE[b], "tw")
    else if (b in TW_LEADING) emit_decl(line, blk, tag, "line-height", TW_LEADING[b], "tw")
    else if (b ~ /^duration-[0-9]+$/) emit_decl(line, blk, tag, "transition-duration", substr(b, 10) "ms", "tw")
    else if (b ~ /^text-/ && (c = tw_color(substr(b, 6))) != "") emit_decl(line, blk, tag, "color", c, "tw")
    else if (b ~ /^bg-/ && (c = tw_color(substr(b, 4))) != "") emit_decl(line, blk, tag, "background-color", c, "tw")
    else if (b ~ /^[a-z][-a-z]*-\[.+\]$/) tw_arbitrary(b, line, blk, tag)
}

function tw_color(name) {
    return (name in TW_COLOR) ? TW_COLOR[name] : ""
}

function tw_arbitrary(b, line, blk, tag,   k, util, v, prop, iscolor) {
    k = index(b, "-[")
    util = substr(b, 1, k - 1)
    v = substr(b, k + 2, length(b) - k - 2)
    gsub(/_/, " ", v)
    iscolor = (v ~ /^(#|rgb|hsl)/)
    prop = ""
    if (util == "text") prop = iscolor ? "color" : "font-size"
    else if (util == "bg" && iscolor) prop = "background-color"
    else if (util == "leading") prop = "line-height"
    else if (util == "font") { prop = (v ~ /^[0-9]+$/) ? "font-weight" : "font-family"; gsub(/["']/, "", v) }
    else if (util == "shadow") prop = "box-shadow"
    else if (util == "duration") prop = "transition-duration"
    else if (util == "max-w") prop = "max-width"
    else if (util ~ /^p[xytrblse]?$/) prop = "padding"
    else if (util ~ /^m[xytrblse]?$/ || util ~ /^space-[xy]$/) prop = "margin"
    else if (util ~ /^gap(-[xy])?$/) prop = "gap"
    if (prop != "") emit_decl(line, blk, tag, prop, v, "twa")
}

function tw_init(   names, sizes, shades, fam, i, j, hex, f) {
    TW_READY = 1
    split("xs 12px sm 14px base 16px lg 18px xl 20px 2xl 24px 3xl 30px 4xl 36px 5xl 48px 6xl 60px 7xl 72px 8xl 96px 9xl 128px", sizes, " ")
    for (i = 1; i < 26; i += 2) TW_SIZE["text-" sizes[i]] = sizes[i + 1]
    split("none 1 tight 1.25 snug 1.375 normal 1.5 relaxed 1.625 loose 2", sizes, " ")
    for (i = 1; i < 12; i += 2) TW_LEADING["leading-" sizes[i]] = sizes[i + 1]
    TW_COLOR["white"] = "#ffffff"
    TW_COLOR["black"] = "#000000"
    split("50 100 200 300 400 500 600 700 800 900 950", shades, " ")
    fam["slate"] = "f8fafc f1f5f9 e2e8f0 cbd5e1 94a3b8 64748b 475569 334155 1e293b 0f172a 020617"
    fam["gray"] = "f9fafb f3f4f6 e5e7eb d1d5db 9ca3af 6b7280 4b5563 374151 1f2937 111827 030712"
    fam["zinc"] = "fafafa f4f4f5 e4e4e7 d4d4d8 a1a1aa 71717a 52525b 3f3f46 27272a 18181b 09090b"
    fam["neutral"] = "fafafa f5f5f5 e5e5e5 d4d4d4 a3a3a3 737373 525252 404040 262626 171717 0a0a0a"
    fam["stone"] = "fafaf9 f5f5f4 e7e5e4 d6d3d1 a8a29e 78716c 57534e 44403c 292524 1c1917 0c0a09"
    for (f in fam) {
        split(fam[f], hex, " ")
        for (j = 1; j <= 11; j++) TW_COLOR[f "-" shades[j]] = "#" hex[j]
    }
}
