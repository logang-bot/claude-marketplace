# Payload access, hook output, and the lint pipeline. Sourced by every hook, the audit script,
# and the tests.
#
# Adapted from general-code-style's engine.sh: plugins never depend on each other, so the parts
# both need are copied rather than shared.
#
# A hook that cannot run must say so. Exit 2 blocks and exit 0 means "allow, silently", so
# neither fits a missing dependency: exit 1 is the non-blocking-error slot, where the message
# reaches the user and nothing is prevented.

ENGINE_LIB=${ENGINE_LIB:-$(dirname "$0")/lib}

# Numbers in CSS are written with a dot. An awk that honours the locale (gawk --posix, and others
# in POSIX mode) reads "0.6" as 0 under a comma-decimal locale, which would silently pass every
# alpha, duration and line-height check. LC_NUMERIC is pinned to C; LC_ALL would override it, so
# its value moves to LC_CTYPE, which keeps character handling (and so UTF-8 lengths) as the user
# had it.
if [ -n "${LC_ALL:-}" ]; then
    LC_CTYPE=$LC_ALL
    export LC_CTYPE
    unset LC_ALL
fi
LC_NUMERIC=C
export LC_NUMERIC

require_tools() {
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 && continue
        printf '%s\n' "web-design: \`$tool\` is not on PATH, so the design hooks cannot run" \
            "and are not checking anything. Install it, or remove the plugin so the gap is" \
            "not mistaken for a clean bill of health." >&2
        exit 1
    done
}

read_payload() {
    PAYLOAD=$(cat)
}

payload_blank() {
    case $PAYLOAD in
        *[!\ \	]*) return 1 ;;
        *) return 0 ;;
    esac
}

payload_value() {
    printf '%s' "$PAYLOAD" | awk -f "$ENGINE_LIB/json.awk" -v key="$1" 2>/dev/null
}

# Every match for a key that runs through an array, as `<index>\t<value>`.
payload_values() {
    printf '%s' "$PAYLOAD" | awk -f "$ENGINE_LIB/json.awk" -v key="$1" -v all=1 2>/dev/null
}

# Like payload_values, but a multi-line value survives with its newlines turned into \034.
payload_values_nl() {
    printf '%s' "$PAYLOAD" | awk -f "$ENGINE_LIB/json.awk" -v key="$1" -v all=1 -v nl="$(printf '\034')" 2>/dev/null
}

# Text on stdin, one line of hook JSON out. The limit guards the client's 8000-character cap on
# additionalContext, leaving room for escaping to expand what it is given.
emit_context() {
    awk -f "$ENGINE_LIB/jsonout.awk" -v event="$1" -v limit=7000
}

# Windows tools hand back C:\Users\... ; the MSYS2 awk in Git Bash wants forward slashes.
native_path() {
    case $1 in
        [A-Za-z]:[/\\]*) printf '%s\n' "$1" | tr '\\' '/' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

extension_of() {
    _base=${1##*/}
    case $_base in
        *.*) printf '%s\n' "${_base##*.}" | tr 'A-Z' 'a-z' ;;
        *) printf '%s\n' "" ;;
    esac
}

# Generated, vendored and minified files are never the agent's design work.
skipped_path() {
    case /$1 in
        */node_modules/*|*/dist/*|*/build/*|*/.next/*|*/.nuxt/*|*/.svelte-kit/*|*/vendor/*) return 0 ;;
        */coverage/*|*/.git/*|*/out/*|*.min.css|*.min.js|*.d.ts|*.map) return 0 ;;
    esac
    return 1
}

# Files the linter reads. Plain .js/.ts are included because styled-components and JSX live in
# them; a backend .ts file yields no records and so costs nothing but the read.
is_web_path() {
    skipped_path "$1" && return 1
    case $(extension_of "$1") in
        css|scss|less|html|htm|vue|svelte|astro|jsx|tsx|js|ts) return 0 ;;
    esac
    return 1
}

# Files whose first write is worth injecting the rules for: markup and styles only. A plain .ts
# edit in a backend project must not pay for a design digest.
is_design_path() {
    skipped_path "$1" && return 1
    case $(extension_of "$1") in
        css|scss|less|html|htm|vue|svelte|astro|jsx|tsx) return 0 ;;
    esac
    return 1
}

web_filter() {
    while IFS= read -r _p; do
        [ -n "$_p" ] || continue
        is_web_path "$_p" && printf '%s\n' "$_p"
    done
    return 0
}

payload_cwd() {
    _cwd=$(payload_value cwd)
    [ -n "$_cwd" ] || _cwd=$PWD
    native_path "$_cwd"
}

# The repository root, or the directory itself when it is not a repository.
project_root() {
    git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$1"
}

# Whether the project uses Tailwind. Only then are class names read as utilities.
tailwind_in_use() {
    for _cfg in "$1"/tailwind.config.*; do
        [ -f "$_cfg" ] && return 0
    done
    [ -f "$1/package.json" ] && grep -q '"tailwindcss"' "$1/package.json" 2>/dev/null && return 0
    return 1
}

# Normalized records for one file. $1 the file, $2 tailwind 0|1.
extract_records() {
    awk -f "$ENGINE_LIB/common.awk" -f "$ENGINE_LIB/css.awk" -f "$ENGINE_LIB/jsx.awk" \
        -f "$ENGINE_LIB/tailwind.awk" -f "$ENGINE_LIB/markup.awk" -f "$ENGINE_LIB/extract.awk" \
        -v path="$1" -v ext="$(extension_of "$1")" -v tailwind="$2" -- "$1" 2>/dev/null
}

# Paths on stdin, findings out. $1 is the project root, which supplies DESIGN.md and decides
# whether Tailwind classes are read.
lint_files() {
    _root=$1
    _tw=0
    tailwind_in_use "$_root" && _tw=1
    _brief=$(brief_file "$_root") || _brief=""
    _fonts=""; _icon=""; _spacing=""; _radius=""; _types=""; _relax=""
    if [ -n "$_brief" ]; then
        _fonts=$(brief_value "$_brief" font-families | tr -d "\"'")
        _icon=$(brief_value "$_brief" icon-pack)
        _spacing=$(brief_value "$_brief" spacing-scale | tr -c '0-9.\n' ' ')
        _radius=$(brief_value "$_brief" radius | tr -c '0-9.\n' ' ')
        _types=$(brief_value "$_brief" type-scale | tr -c '0-9.\n' ' ')
        _relax=$(brief_value "$_brief" relax | tr -c 'A-Za-z0-9\n-' ' ')
    fi
    while IFS= read -r _f; do
        [ -f "$_f" ] || continue
        extract_records "$_f" "$_tw"
    done | awk -f "$ENGINE_LIB/common.awk" -f "$ENGINE_LIB/color.awk" \
        -f "$ENGINE_LIB/crossfile.awk" -f "$ENGINE_LIB/lint.awk" \
        -v fonts="$_fonts" -v icon="$_icon" -v spacing="$_spacing" \
        -v radius="$_radius" -v typescale="$_types" -v relax="$_relax" 2>/dev/null
}

# Findings in, the hook's bullet list out. $1 the root to show paths relative to, $2 the cap.
report_findings() {
    awk -f "$ENGINE_LIB/report.awk" -v root="$1" -v limit="${2:-8}"
}

# Drops findings already in the set, records the rest. $1 the set file.
unseen_findings() {
    awk -f "$ENGINE_LIB/seen.awk" -v set="$1"
}
