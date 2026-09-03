# Records in, the paths that actually broke a rule out.
#
# `measure.awk` prints a FILE record for every file it measures, not only the oversized ones —
# `report.awk` counts them all to say how many files a sweep covered. The size threshold is
# applied by whoever consumes the records, which means a consumer that wants offending paths
# has to apply it too. Reading `$2` off every record instead is how the 0.8.0 advisory came to
# name four clean files alongside the one that was actually too long.
#
# The predicates mirror the ones in advise.awk. The number itself lives in limits.awk, so the
# cap stays a single definition however many consumers test against it.

BEGIN {
    init_limits()
    FS = "\t"
}

$1 == "FILE" && $3 + 0 > FILE_LIMIT { print $2 }
$1 == "LONG" || $1 == "WIDE" || $1 == "NOTE" { print $2 }
