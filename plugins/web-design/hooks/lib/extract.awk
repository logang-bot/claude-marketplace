# Extraction driver: one file in, normalized records out.
#
#   awk -f common.awk -f css.awk -f jsx.awk -f tailwind.awk -f markup.awk -f extract.awk \
#       -v path=<name to report> -v ext=<extension> -v tailwind=0|1 -- <file>
#
# Records, tab separated:
#
#   D path line block selector property value source   a CSS declaration
#   M path line kind detail                            a markup fact
#
# The whole file is read before anything is scanned, because the constructs that matter span
# lines: a <style> block, a JSX style object, a styled-components template, a class attribute
# broken over several lines. LSTART holds where each line starts in TXT, so a scanner working
# on absolute positions can still report the line a finding is on.
#
# Every source is normalized to the same D record so lint.awk has one set of rules, whether a
# weight came from `font-weight: 300`, `fontWeight: 300`, or `font-light`.

BEGIN { TPOS = 1 }

{
    LSTART[NR] = TPOS
    LN[NR] = $0
    TXT = TXT $0 "\n"
    TPOS += length($0) + 1
}

END {
    if (NR == 0) exit
    extract_main()
}

function extract_main(   e) {
    NL = NR
    BLOCK = 0
    e = tolower(ext)
    if (e ~ /^(css|scss|less)$/) css_scan(1, length(TXT), "", "css")
    else {
        markup_scan()
        if (e ~ /^(jsx|tsx|js|ts|vue|svelte|astro)$/) styled_literals()
    }
    icon_imports()
}
