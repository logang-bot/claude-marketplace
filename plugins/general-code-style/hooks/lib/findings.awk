# The advisory text for each kind of finding, and the cap on how much of it is shown.

function file_warning(path, code_lines) {
    return path " is " code_lines " lines excluding imports (cap is ~200, " FILE_LIMIT \
           " with spare). Split it into child classes or files with focused " \
           "responsibilities."
}

function length_warning(path, name, line, body) {
    return path ":" line " function `" name "` has a " body "-line body (cap is ~7, " \
           FUNCTION_LIMIT " with spare). Extract the steps into named helpers."
}

function parameter_warning(path, name, line, params) {
    return path ":" line " function `" name "` takes " params " parameters (max is " \
           PARAM_LIMIT "). Group the related extras into a data class, or the equivalent " \
           "record, struct, or interface."
}

function comment_warning(path, line, text) {
    return path ":" line " explains code with a comment — `" substr(text, 1, 60) \
           "`. Rename the value or extract a named helper so the code says it; only a " \
           "tool directive, a TODO/FIXME, or doc-comment on non-obvious math belongs here."
}

# Keep the advisory short — a full listing is what the sweep is for. `scope` names where
# the hidden findings are, which differs between one file and a set of them.
function more_findings(hidden, scope) {
    return "…and " hidden " more findings" (scope == "" ? "" : " " scope) "."
}
