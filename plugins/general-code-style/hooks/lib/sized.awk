# FILE records in, one compact line each out.
#
# Deliberately not findings.awk's `file_warning`, which ends "Split it into child classes or
# files with focused responsibilities." That instruction is right for a plan and wrong for a
# hook: splitting a file mid-request is the derailment the routing exists to prevent, and at
# Stop the work is already finished. These lines state the size and stop there — what to do
# about it is the user's call, and the surrounding text says so.
BEGIN {
    init_limits()
    FS = "\t"
}

$1 == "FILE" { printf "%s is %s lines, over the %d-line cap.\n", $2, $3, FILE_LIMIT }
