# Rule 5, the mechanical half: explanatory comments inside a function body.
#
# Only bodies are examined, so a licence banner, a file header, and a doc comment above a
# declaration are out of scope by construction. Whether a doc comment states something its
# member's name already says is a judgement about the reader, and stays with the reviewer
# agent.

function body_comments(s, e,   i, inside) {
    inside = 0
    if (e > NL) e = NL
    for (i = s; i <= e; i++) {
        comment_on(L[i], inside)
        inside = CO_INSIDE
        if (CO_TEXT != "" && !is_allowed(CO_TEXT)) {
            CN++
            CLINE[CN] = i
            CTEXT[CN] = CO_TEXT
        }
    }
}

function sort_findings(   i, j, line, text) {
    for (i = 2; i <= CN; i++) {
        line = CLINE[i]; text = CTEXT[i]
        for (j = i - 1; j >= 1 && CLINE[j] > line; j--) {
            CLINE[j + 1] = CLINE[j]; CTEXT[j + 1] = CTEXT[j]
        }
        CLINE[j + 1] = line; CTEXT[j + 1] = text
    }
}

# Consecutive comment lines are one comment, so they are reported once.
function collapse_runs(   i, kept) {
    kept = 0
    for (i = 1; i <= CN; i++) {
        if (kept == 0 || CLINE[i] > CLINE[kept] + 1) {
            kept++
            CLINE[kept] = CLINE[i]
            CTEXT[kept] = CTEXT[i]
        }
    }
    CN = kept
}

# Fills CLINE[1..CN] / CTEXT[1..CN] with every explanatory comment inside a body.
function comment_findings(ext,   k) {
    CN = 0
    for (k = 1; k <= FN_N; k++) body_comments(FN_S[k], FN_E[k])
    sort_findings()
    collapse_runs()
}
