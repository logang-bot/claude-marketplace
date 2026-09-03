# Emits a hook's additionalContext as JSON. The write-side counterpart to json.awk.
#
#   printf '%s' "$text" | awk -f jsonout.awk -v event=SubagentStart -v limit=7000
#
# The escaping is a left-to-right character scan rather than a series of gsubs, for the
# reason json.awk documents on the read side: each gsub pass rewrites the text the next one
# reads, so an earlier substitution can manufacture a sequence a later one then mangles.
#
# `limit` truncates the text before it is escaped, never after — cutting escaped output
# could sever a `\uXXXX` in the middle and produce a payload that will not parse. It guards
# the 8000-character cap the client puts on additionalContext.

function control_map(   i) {
    for (i = 1; i < 32; i++) CTRL[sprintf("%c", i)] = sprintf("\\u%04x", i)
}

function escape(s,   out, i, n, c) {
    out = ""
    n = length(s)
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\") out = out "\\\\"
        else if (c == "\"") out = out "\\\""
        else if (c == "\n") out = out "\\n"
        else if (c == "\t") out = out "\\t"
        else if (c == "\r") out = out "\\r"
        else if (c in CTRL) out = out CTRL[c]
        else out = out c
    }
    return out
}

BEGIN { control_map() }

{ DOC = DOC $0 "\n" }

END {
    if (event == "") exit 1
    if (limit + 0 > 0 && length(DOC) > limit + 0) DOC = substr(DOC, 1, limit + 0)
    printf "{\"hookSpecificOutput\":{\"hookEventName\":\"%s\",\"additionalContext\":\"%s\"}}\n", \
        event, escape(DOC)
}
