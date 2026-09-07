# Narrows measurement records to the findings a turn actually introduced.
#
#   awk -f limits.awk -f keys.awk -f introduced.awk -v base=<baseline key file>
#
# Records in on stdin, the same records out, minus everything that was already true before the
# turn started. This is what stops the hooks ordering a refactor of code the turn inherited:
# touching one line of a file that has been 289 lines for months now reports nothing, while a
# file the turn pushes over the cap still does.
#
# Baseline keys come from keys.awk, either recorded at the start of the request or measured
# from `git show HEAD:<path>`. A missing baseline means the file did not exist before, so every
# finding in it belongs to the turn — the same answer, reached by the array simply being empty.
#
# Counted, not matched. Two overloads already over the body cap put `LONG:<name>` in the
# baseline twice; a third is reported because the count rose, and a rename of one of them is
# reported because the new name has no baseline count at all.
#
# File size is the exception, and gets `file_introduced()` instead of a count. A file is either
# pushed over the cap by this turn, or grown well past where it already was; an inherited
# violation that merely persists is not the turn's to answer for.

function file_introduced(   now) {
    now = $3 + 0
    if (!HAVE_LINES) return 1                       # no baseline: the file is new
    if (BASE_LINES <= FILE_LIMIT) return 1          # the turn crossed the cap
    return (now - BASE_LINES > GROWTH_LIMIT)        # already over, and the turn piled on
}

BEGIN {
    init_limits()
    FS = "\t"
    HAVE_LINES = 0
    if (base != "") {
        while ((getline line < base) > 0) {
            if (line == "") continue
            if (index(line, "LINES:") == 1) {
                BASE_LINES = substr(line, 7) + 0
                HAVE_LINES = 1
                continue
            }
            BASE[line]++
        }
        close(base)
    }
}

{
    key = key_of()
    if (key == "") next
    if (key == "FILE") {
        if (file_introduced()) print
        next
    }
    SEEN[key]++
    if (SEEN[key] > BASE[key]) print
}
