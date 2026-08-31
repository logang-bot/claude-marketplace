# Classifies changed files as code or documentation.
#
# Prints "code" once per changed code file, and "doc" once if any documentation changed.
# A file counts as documentation if it sits under docs/ or carries a prose extension.

BEGIN {
    n = split("kt java swift js jsx ts tsx py go rs rb php cs c cc cpp h hpp scala sql",
              named, " ")
    for (i = 1; i <= n; i++) CODE[named[i]] = 1
    n = split("md mdx rst adoc txt", named, " ")
    for (i = 1; i <= n; i++) DOC[named[i]] = 1
}

$0 == "" { next }

{
    base = $0
    sub(/.*\//, "", base)
    ext = ""
    if (base ~ /\./) { ext = base; sub(/.*\./, "", ext) }
    if (index($0, "docs/") == 1 || (ext in DOC)) { seen_doc = 1; next }
    if (ext in CODE) print
}

END { if (seen_doc) print "__DOC__" }
