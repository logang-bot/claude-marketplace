# Stable identity keys for measurement records, so a finding can be recognised across an edit.
#
# The hooks report only what a turn introduced, which means comparing the findings in a file
# now against the findings in it before the turn started. Line numbers are useless for that —
# inserting one line at the top shifts every finding below it — so each record is reduced to
# an identity that survives the shift:
#
#   FILE over the cap   ->  FILE                 (presence; the size test lives in introduced.awk)
#   any FILE record     ->  LINES:<code lines>   (emitted alongside, for the growth test)
#   LONG                ->  LONG:<function name>
#   WIDE                ->  WIDE:<function name>
#   NOTE                ->  NOTE:<comment text>
#
# Names rather than positions, and counted rather than matched: two overloads of the same name
# both too long give the key a count of 2, so a turn that adds a third is caught while a turn
# that merely moves them is not.
#
# `:` separates type from identity, not a tab, because these keys are stored one per line in a
# snapshot whose own fields are tab separated. Text is flattened and truncated for the same
# reason — a comment carrying a tab or a newline would otherwise break the record it sits in.
#
# Loaded two ways. With `-v emit=1` the rules print the keys, which is how the snapshot is
# built; without it the rules are inert and only `key_of()` is borrowed, which is how
# introduced.awk reads the same identity off a live record.

function key_clean(s) {
    gsub(/[\t\n\r]/, " ", s)
    return substr(s, 1, 60)
}

# A NOTE's text is everything past the line number, which may itself have held tabs.
function key_note(   i, out) {
    out = $4
    for (i = 5; i <= NF; i++) out = out " " $i
    return out
}

# The identity of the record in $0, or "" for one that carries none — which a FILE record
# under the cap does, since there is no finding in it to identify.
function key_of(   type) {
    type = $1
    if (type == "FILE") return ($3 + 0 > FILE_LIMIT) ? "FILE" : ""
    if (type == "LONG") return "LONG:" key_clean($3)
    if (type == "WIDE") return "WIDE:" key_clean($3)
    if (type == "NOTE") return "NOTE:" key_clean(key_note())
    return ""
}

BEGIN {
    init_limits()
    FS = "\t"
}

emit != "" && $1 == "FILE" { print "LINES:" ($3 + 0) }

emit != "" {
    key = key_of()
    if (key != "") print key
}
