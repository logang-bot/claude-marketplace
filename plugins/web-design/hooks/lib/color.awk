# Colour parsing and WCAG contrast. Function library for lint.awk.
#
# color_parse() reads one colour token (#rgb, #rgba, #rrggbb, #rrggbbaa, rgb()/rgba() in comma
# or space syntax, hsl()/hsla(), and a handful of named colours) into CR CG CB (0-255) and CA
# (0-1). POSIX awk has no strtonum, so hex is decoded by hand, and no regex intervals are used
# because the BWK awk macOS ships does not reliably support them.
#
# Contrast follows WCAG 2: relative luminance from linearised sRGB, ratio (L1 + 0.05) / (L2 +
# 0.05). A translucent text colour is composited over its background first; a translucent
# background has nothing known beneath it, so the pair is not judged at all.

function color_init(   names, n, i, pairs) {
    COLOR_READY = 1
    names = "aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen"
    n = split(names, pairs, " ")
    for (i = 1; i <= n; i++) COLOR_NAMED[pairs[i]] = 1
    n = split("white #ffffff black #000000 gray #808080 grey #808080 silver #c0c0c0 red #ff0000 blue #0000ff green #008000 yellow #ffff00 orange #ffa500 purple #800080 navy #000080 maroon #800000 teal #008080 lightgray #d3d3d3 lightgrey #d3d3d3 darkgray #a9a9a9 darkgrey #a9a9a9 dimgray #696969 dimgrey #696969 whitesmoke #f5f5f5 gainsboro #dcdcdc", pairs, " ")
    for (i = 1; i < n; i += 2) COLOR_HEX[pairs[i]] = pairs[i + 1]
}

function color_hexval(h,   i, v, d) {
    v = 0
    h = tolower(h)
    for (i = 1; i <= length(h); i++) {
        d = index("0123456789abcdef", substr(h, i, 1)) - 1
        if (d < 0) return -1
        v = v * 16 + d
    }
    return v
}

function color_parse(s,   h, n, parts, body) {
    if (!COLOR_READY) color_init()
    s = tolower(str_trim(s))
    if (s ~ /^#[0-9a-f]+$/) {
        h = substr(s, 2)
        n = length(h)
        if (n == 3 || n == 4) {
            CR = color_hexval(substr(h, 1, 1)) * 17
            CG = color_hexval(substr(h, 2, 1)) * 17
            CB = color_hexval(substr(h, 3, 1)) * 17
            CA = (n == 4) ? color_hexval(substr(h, 4, 1)) * 17 / 255 : 1
            return 1
        }
        if (n == 6 || n == 8) {
            CR = color_hexval(substr(h, 1, 2))
            CG = color_hexval(substr(h, 3, 2))
            CB = color_hexval(substr(h, 5, 2))
            CA = (n == 8) ? color_hexval(substr(h, 7, 2)) / 255 : 1
            return 1
        }
        return 0
    }
    if (s ~ /^(rgba?|hsla?)\(/) {
        body = s
        sub(/^[a-z]+\(/, "", body)
        sub(/\).*$/, "", body)
        gsub(/[,\/]/, " ", body)
        n = split(body, parts, " ")
        if (n < 3) return 0
        CA = (n >= 4) ? color_alpha(parts[4]) : 1
        if (s ~ /^rgb/) {
            CR = color_chan(parts[1]); CG = color_chan(parts[2]); CB = color_chan(parts[3])
            return (CR >= 0 && CG >= 0 && CB >= 0)
        }
        return color_hsl(parts[1] + 0, parts[2] + 0, parts[3] + 0)
    }
    if (s == "transparent") { CR = 0; CG = 0; CB = 0; CA = 0; return 1 }
    if (s in COLOR_HEX) return color_parse(COLOR_HEX[s])
    return 0
}

function color_chan(t) {
    if (t ~ /^[0-9.]+%$/) return (t + 0) * 2.55
    if (t ~ /^[0-9.]+$/) return t + 0
    return -1
}

function color_alpha(t) {
    if (t ~ /%$/) return (t + 0) / 100
    return t + 0
}

function color_abs(x) {
    return x < 0 ? -x : x
}

function color_hsl(hue, sat, lig,   c, x, m, r, g, b, hp) {
    hue = hue - 360 * int(hue / 360)
    if (hue < 0) hue += 360
    sat /= 100; lig /= 100
    c = (1 - color_abs(2 * lig - 1)) * sat
    hp = hue / 60
    x = c * (1 - color_abs(hp - 2 * int(hp / 2) - 1))
    if (hp < 1) { r = c; g = x; b = 0 }
    else if (hp < 2) { r = x; g = c; b = 0 }
    else if (hp < 3) { r = 0; g = c; b = x }
    else if (hp < 4) { r = 0; g = x; b = c }
    else if (hp < 5) { r = x; g = 0; b = c }
    else { r = c; g = 0; b = x }
    m = lig - c / 2
    CR = (r + m) * 255; CG = (g + m) * 255; CB = (b + m) * 255
    return 1
}

function color_is_named(word) {
    if (!COLOR_READY) color_init()
    return (tolower(word) in COLOR_NAMED)
}

# The first colour token in a value, or "". A gradient or an image has no single colour, so a
# background made of one yields nothing rather than a misleading first stop.
function color_first(v,   best, pos, t, n, i, words) {
    if (!COLOR_READY) color_init()
    v = tolower(v)
    if (v ~ /gradient\(|url\(/) return ""
    best = ""; pos = 0
    if (match(v, /#[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*/)) { best = substr(v, RSTART, RLENGTH); pos = RSTART }
    if (match(v, /(rgba?|hsla?)\([^)]*\)/) && (pos == 0 || RSTART < pos)) { best = substr(v, RSTART, RLENGTH); pos = RSTART }
    n = split(v, words, /[ ,()]+/)
    for (i = 1; i <= n; i++) {
        t = words[i]
        if (t == "" || !(t in COLOR_HEX) && t != "transparent") continue
        if (pos == 0 || index(v, t) < pos) best = t
        break
    }
    return best
}

function color_lin(c) {
    c = c / 255
    return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4
}

function color_lum(r, g, b) {
    return 0.2126 * color_lin(r) + 0.7152 * color_lin(g) + 0.0722 * color_lin(b)
}

# Contrast ratio of fg over bg, or -1 when either cannot be judged.
function color_contrast(fg, bg,   br, bgg, bb, fr, fgg, fb, a, l1, l2) {
    if (!color_parse(bg) || CA < 0.99) return -1
    br = CR; bgg = CG; bb = CB
    if (!color_parse(fg)) return -1
    a = CA
    fr = CR * a + br * (1 - a)
    fgg = CG * a + bgg * (1 - a)
    fb = CB * a + bb * (1 - a)
    l1 = color_lum(fr, fgg, fb)
    l2 = color_lum(br, bgg, bb)
    return (l1 > l2) ? (l1 + 0.05) / (l2 + 0.05) : (l2 + 0.05) / (l1 + 0.05)
}
