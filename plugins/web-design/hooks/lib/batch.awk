# Picks the files a PostToolBatch actually wrote, out of every call in the batch, and says
# which tool wrote each one.
#
# Input is a tagged stream, one record per line, tab separated:
#
#   NAME <index> <tool name>
#   PATH <index> <candidate path>
#
# Output is `<tool name>\t<path>` per written file. The tool name matters here, unlike in
# general-code-style's copy: a Write hands over the whole file as the agent's own work, while
# an Edit only owns the lines in its new_string, and check-batch.sh scopes findings by that.
#
# Several path keys are read into the stream and the first PATH line for an index wins, in
# the order the caller tried the spellings. The write-tool filter lives here rather than in a
# hooks.json matcher because a PostToolBatch matcher must match every call in the batch, so one
# Read alongside a Write would skip the hook entirely.

BEGIN {
    FS = "\t"
    n = split("Write Edit MultiEdit", t, " ")
    for (i = 1; i <= n; i++) WRITES[t[i]] = 1
    MAX = 0
}
$1 == "NAME" || $1 == "PATH" { if ($2 + 0 > MAX) MAX = $2 + 0 }
$1 == "NAME" { NAME[$2 + 0] = $3; next }
$1 == "PATH" { if (!(($2 + 0) in FIRST)) FIRST[$2 + 0] = $3 }
END {
    for (i = 1; i <= MAX; i++) {
        if (!(i in NAME) || !(i in FIRST)) continue
        if (NAME[i] in WRITES) printf "%s\t%s\n", NAME[i], FIRST[i]
    }
}
