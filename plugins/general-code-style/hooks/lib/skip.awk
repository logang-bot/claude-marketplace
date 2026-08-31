# Drops paths that pass through a directory holding build output or dependencies rather
# than code anyone wrote. Compares whole path components, so a file named `build.kt` is
# kept while `build/Main.kt` is not.

BEGIN {
    n = split(".git .gradle .idea __pycache__ node_modules build dist out target venv " \
              ".venv Pods vendor", named, " ")
    for (i = 1; i <= n; i++) SKIP[named[i]] = 1
}

{
    n = split($0, parts, "/")
    keep = 1
    for (i = 1; i <= n; i++) if (parts[i] in SKIP) keep = 0
    if (keep) print
}
