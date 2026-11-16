# The project's design brief, DESIGN.md at the project root.
#
# The brief records the personality and the tokens chosen for it. Only its fenced `tokens` block
# is machine-read, one `key: value` per line:
#
#   ```tokens
#   personality: startup-upbeat
#   font-families: Inter, Merriweather
#   icon-pack: lucide
#   spacing-scale: 4 8 12 16 24 32 48 64 96
#   ```
#
# Everything outside that block is prose for people and for the agents. A brief without the block
# still counts as present — the create-or-decide question stops — it just supplies nothing to check against.

brief_file() {
    [ -n "$1" ] && [ -f "$1/DESIGN.md" ] && printf '%s\n' "$1/DESIGN.md" && return 0
    return 1
}

# The value of one key inside the tokens block, or nothing.
brief_value() {
    awk -v key="$2" '
        on && /^```/ { exit }
        on {
            k = $0; sub(/:.*/, "", k); gsub(/[ \t]/, "", k)
            if (tolower(k) == key) { v = $0; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); print v; exit }
        }
        /^```[ \t]*tokens[ \t]*$/ { on = 1 }
    ' "$1" 2>/dev/null
}
