# Payload reading shared by this plugin's hooks.
#
# json.awk is a copy of the one in general-code-style rather than a shared import: the two
# plugins install independently, so neither may depend on the other being present.
#
# A hook that cannot run must say so. The exit-code contract makes 2 block the tool call
# and 0 mean "allow, silently", so neither fits a missing dependency: exit 1 is the
# non-blocking-error slot, where the message reaches the user and nothing is prevented.

HOOK_LIB=${HOOK_LIB:-$(dirname "$0")/lib}

require_tools() {
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 && continue
        printf '%s\n' "dev-workflow: \`$tool\` is not on PATH, so this hook cannot run and" \
            "is not guarding anything. Install it, or remove the plugin so the gap is not" \
            "mistaken for a clean bill of health." >&2
        exit 1
    done
}

read_payload() {
    PAYLOAD=$(cat)
}

payload_is_object() {
    case $(printf '%s' "$PAYLOAD" | tr -d ' \t\n') in
        \{*) return 0 ;;
        *) return 1 ;;
    esac
}

payload_value() {
    printf '%s' "$PAYLOAD" | awk -f "$HOOK_LIB/json.awk" -v key="$1" 2>/dev/null
}
