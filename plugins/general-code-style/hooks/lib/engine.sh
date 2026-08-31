# Locates the awk modules and runs them. Sourced by the hooks, the sweep, and the tests.
#
# A hook that cannot run must say so. The exit-code contract makes 2 block the tool call
# and 0 mean "allow, silently", so neither fits a missing dependency: exit 1 is the
# non-blocking-error slot, where the message reaches the user and nothing is prevented.
# Failing silently here is the bug that made the Python hooks look like they were working.

ENGINE_LIB=${ENGINE_LIB:-$(dirname "$0")/lib}

require_tools() {
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 && continue
        printf '%s\n' "general-code-style: \`$tool\` is not on PATH, so the style hooks" \
            "cannot run and are not checking anything. Install it, or remove the plugin" \
            "so the gap is not mistaken for a clean bill of health." >&2
        exit 1
    done
}

# Windows tools hand back C:\Users\... ; the MSYS2 awk in Git Bash wants forward slashes.
# Only a drive-lettered path is rewritten, so a Unix filename containing a backslash is
# left exactly as it is.
native_path() {
    case $1 in
        [A-Za-z]:[/\\]*) printf '%s\n' "$1" | tr '\\' '/' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

extension_of() {
    _base=${1##*/}
    case $_base in
        *.*) printf '%s\n' "${_base##*.}" ;;
        *) printf '%s\n' "" ;;
    esac
}

# Measurement records for one file. $1 is the file to read, $2 the path to name it by.
measure_records() {
    awk -f "$ENGINE_LIB/limits.awk" \
        -f "$ENGINE_LIB/text.awk" \
        -f "$ENGINE_LIB/sizes.awk" \
        -f "$ENGINE_LIB/blocks.awk" \
        -f "$ENGINE_LIB/comments.awk" \
        -f "$ENGINE_LIB/measure.awk" \
        -v path="$2" -v ext="$(extension_of "$2")" -- "$1"
}

# Records in, advisory lines out. $1 names where hidden findings live, or is empty.
advise_records() {
    awk -f "$ENGINE_LIB/limits.awk" \
        -f "$ENGINE_LIB/findings.awk" \
        -f "$ENGINE_LIB/advise.awk" \
        -v scope="$1"
}

payload_value() {
    printf '%s' "$PAYLOAD" | awk -f "$ENGINE_LIB/json.awk" -v key="$1" 2>/dev/null
}

read_payload() {
    PAYLOAD=$(cat)
}
