# Picks the files a PostToolBatch actually wrote, out of every call in the batch.
#
# Input is a tagged stream, one record per line, tab separated:
#
#   NAME <index> <tool name>
#   PATH <index> <candidate path>
#
# Tools disagree about what to call the file they wrote, so several path keys are read into
# this stream and more than one PATH line can arrive for an index; the first one wins, which
# is the order the caller tried the spellings in.
#
# The write-tool filter lives here rather than in a hooks.json matcher because a
# PostToolBatch matcher has to match *every* call in the batch: one Read alongside a Write
# would skip the hook entirely. Filtering after the fact is what keeps a batch that merely
# read a long file from being measured, which would turn the advisory into a nag.

BEGIN {
    FS = "\t"
    n = split("Write Edit MultiEdit NotebookEdit", t, " ")
    for (i = 1; i <= n; i++) WRITES[t[i]] = 1
    MAX = 0
}

$1 == "NAME" || $1 == "PATH" { if ($2 + 0 > MAX) MAX = $2 + 0 }

$1 == "NAME" { NAME[$2 + 0] = $3; next }
$1 == "PATH" { if (!(($2 + 0) in FIRST)) FIRST[$2 + 0] = $3 }

END {
    for (i = 1; i <= MAX; i++) {
        if (!(i in NAME) || !(i in FIRST)) continue
        if (NAME[i] in WRITES) print FIRST[i]
    }
}
