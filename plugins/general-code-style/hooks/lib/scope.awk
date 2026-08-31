# Filters a list of paths on stdin down to the source files the rules measure.
#
# Reads its scope from limits.awk rather than restating it, so the hooks, the sweep, and
# the tests can never disagree about what counts as a source file.

BEGIN { init_limits() }

$0 == "" { next }

{
    base = $0
    sub(/.*[\/\\]/, "", base)
    ext = ""
    if (base ~ /\./) { ext = base; sub(/.*\./, "", ext) }
    if (ext in SOURCE) print
}
