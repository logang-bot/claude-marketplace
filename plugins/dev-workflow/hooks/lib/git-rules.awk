# Decides whether a Bash command writes history or publishes on the user's behalf.
#
# Reads the command on stdin and prints the name of the first blocked command, or nothing.
# The command arrives on stdin rather than through -v because awk expands escape sequences
# in a -v value, which would rewrite backslashes in the command being judged.
#
# Matching is anchored to the subcommand slot. An earlier version matched patterns anywhere
# in a segment, which denied read-only commands like `git log --grep=commit`.

function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
}

# A run of short flags carries each one it clusters, so `-xdf` counts as `-f`. Only
# lowercase short flags cluster; -B and -D are their own options.
function has_flag(rest, flags,   toks, fl, n, nf, i, j, run) {
    nf = split(flags, fl, " ")
    n = split(rest, toks, " ")
    for (i = 1; i <= n; i++) {
        run = (toks[i] ~ /^-[a-zA-Z]+$/)
        for (j = 1; j <= nf; j++) {
            if (toks[i] == fl[j]) return 1
            if (!run || length(fl[j]) != 2 || fl[j] !~ /^-[a-z]$/) continue
            if (index(substr(toks[i], 2), substr(fl[j], 2, 1)) > 0) return 1
        }
    }
    return 0
}

function has_word(rest, words,   toks, wl, n, nw, i, j) {
    nw = split(words, wl, " ")
    n = split(rest, toks, " ")
    for (i = 1; i <= n; i++)
        for (j = 1; j <= nw; j++)
            if (toks[i] == wl[j]) return 1
    return 0
}

# Leading `git`, any global options including the ones that take a value, then the
# subcommand. The global-option run is what lets `git -C /path <write>` be caught: without
# it, -C would be mistaken for the subcommand. Sets GIT_SUB and GIT_REST.
function git_parts(segment,   s) {
    s = segment
    if (s !~ /^[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]/) return 0
    sub(/^[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]+/, "", s)
    while (1) {
        if (match(s, /^-[cC][[:space:]]+[^[:space:]]+[[:space:]]+/)) { s = substr(s, RLENGTH + 1); continue }
        if (match(s, /^--(git-dir|work-tree|namespace|exec-path)(=[^[:space:]]*|[[:space:]]+[^[:space:]]+)[[:space:]]+/)) { s = substr(s, RLENGTH + 1); continue }
        if (match(s, /^-[^[:space:]]+[[:space:]]+/)) { s = substr(s, RLENGTH + 1); continue }
        break
    }
    if (!match(s, /^[A-Za-z0-9_-]+/)) return 0
    GIT_SUB = substr(s, 1, RLENGTH)
    GIT_REST = substr(s, RLENGTH + 1)
    return 1
}

function git_violation(segment,   sub_name, rest) {
    if (!git_parts(segment)) return ""
    sub_name = GIT_SUB
    rest = GIT_REST
    if (sub_name in ALWAYS) return ALWAYS[sub_name]
    if (sub_name == "tag") return has_flag(rest, "-l --list") ? "" : NAMED["tag"]
    if (sub_name == "reset") return has_flag(rest, "--hard") ? NAMED["reset"] : ""
    if (sub_name == "checkout") return has_flag(rest, "-b -B") ? NAMED["checkout"] : ""
    if (sub_name == "switch") return has_flag(rest, "-c -C") ? NAMED["switch"] : ""
    if (sub_name == "branch") return has_flag(rest, "-d -D") ? NAMED["branch"] : ""
    if (sub_name == "stash") return has_word(rest, "drop clear pop") ? NAMED["stash"] : ""
    if (sub_name == "clean") return has_flag(rest, "-f") ? NAMED["clean"] : ""
    return ""
}

# `gh` subcommands that publish on the user's behalf.
function gh_violation(segment,   i, verbs) {
    for (i = 1; i <= GH_N; i++)
        if (segment ~ ("^[[:space:]]*gh[[:space:]]+" GH_NOUN[i] "[[:space:]]+(" GH_VERBS[i] ")([^A-Za-z0-9_]|$)"))
            return "gh " GH_NOUN[i]
    return ""
}

# Segments split on &&, ||, ; and | — the two-character operators first, so || is never
# read as two empty pipes.
function split_segments(cmd,   i, n, c, two, seg) {
    SEG_N = 0
    seg = ""
    n = length(cmd)
    i = 1
    while (i <= n) {
        two = substr(cmd, i, 2)
        c = substr(cmd, i, 1)
        if (two == "&&" || two == "||") { SEGS[++SEG_N] = seg; seg = ""; i += 2; continue }
        if (c == ";" || c == "|") { SEGS[++SEG_N] = seg; seg = ""; i++; continue }
        seg = seg c
        i++
    }
    SEGS[++SEG_N] = seg
}

function find_violation(cmd,   i, seg, found) {
    split_segments(cmd)
    for (i = 1; i <= SEG_N; i++) {
        seg = trim(SEGS[i])
        found = gh_violation(seg)
        if (found == "") found = git_violation(seg)
        if (found != "") return found
    }
    return ""
}

function init_rules(   i, n, names) {
    n = split("commit push merge rebase revert cherry-pick filter-branch", names, " ")
    for (i = 1; i <= n; i++) ALWAYS[names[i]] = "git " names[i]

    NAMED["tag"] = "git tag"
    NAMED["reset"] = "git reset --hard"
    NAMED["checkout"] = "git checkout -b"
    NAMED["switch"] = "git switch -c"
    NAMED["branch"] = "git branch -d"
    NAMED["stash"] = "git stash drop/clear/pop"
    NAMED["clean"] = "git clean -f"

    GH_N = 4
    GH_NOUN[1] = "pr";      GH_VERBS[1] = "create|merge|close|edit|ready|review"
    GH_NOUN[2] = "release"; GH_VERBS[2] = "create|delete|edit|upload"
    GH_NOUN[3] = "repo";    GH_VERBS[3] = "create|delete|edit|rename"
    GH_NOUN[4] = "issue";   GH_VERBS[4] = "create|close|edit|comment"
}

BEGIN { init_rules() }

{ CMD = (NR == 1) ? $0 : CMD "\n" $0 }

END {
    found = find_violation(CMD)
    if (found != "") printf "%s\n", found
    exit (found != "") ? 0 : 1
}
