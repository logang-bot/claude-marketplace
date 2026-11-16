# Drops findings already raised, and records the ones it lets through.
#
#   awk -f seen.awk -v set=<file>
#
# The set is keyed by the finding's own key, not its line, so a finding that moves when lines
# are added above it is still recognised. It is shared by check-batch.sh and check-turn.sh, so a
# finding told at the write is not told again at Stop. With no set file, everything passes.

BEGIN {
    FS = "\t"
    if (set != "") while ((getline SEEN_LINE < set) > 0) SEEN[SEEN_LINE] = 1
    if (set != "") close(set)
}

$1 == "F" {
    if ($6 in SEEN) next
    SEEN[$6] = 1
    print
    if (set != "") print $6 >> set
}
