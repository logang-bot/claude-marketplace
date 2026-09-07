# Drops the findings already raised during this request, and records the ones it lets through.
#
#   awk -f limits.awk -f keys.awk -f unseen.awk -v set=<reported-set file>
#
# Records in, records out. Two hooks share one set, and that sharing is what the routing in
# check-new-files.sh rests on: a local finding PostToolBatch already ordered a fix for is in the
# set, so Stop stays quiet about it, while one from a write that carried no path — a heredoc, a
# generator script, an MCP server — was never seen by anything and survives to be ordered there.
#
# Identity is `path` plus the key from keys.awk, never the line number, so re-editing a file and
# shifting a finding down twenty lines does not make it look new.
#
# Without a set every record passes. The set only decides whether something is said twice, so
# losing it costs a repeated line rather than a missed finding.

BEGIN {
    init_limits()
    FS = "\t"
    if (set != "") {
        while ((getline line < set) > 0) SEEN[line] = 1
        close(set)
    }
}

{
    key = key_of()
    if (key == "") next
    id = $2 "\t" key
    if (id in SEEN) next
    SEEN[id] = 1
    FRESH[id] = 1
    print
}

END {
    if (set == "") exit
    for (id in FRESH) print id >> set
}
