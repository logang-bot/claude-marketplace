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

# One sentence per reason, each naming the move that settles it. The tiers are spelled out
# rather than referred to, because this is the only place a reader meets them.
function order_warning(path, name, line, reason) {
    if (reason == "property-below-method")
        return path ":" line " property `" name "` is declared among the methods. Move it " \
               "into the property block at the top: properties, then constructors, then methods."
    if (reason == "property-visibility")
        return path ":" line " property `" name "` is more visible than one declared above " \
               "it. Order properties widest first — public, then internal, then protected, " \
               "then private."
    return path ":" line " method `" name "` is more visible than one declared above it. " \
           "Order methods widest first — public, then internal, then protected, then " \
           "private — and within a tier put each helper below the method that calls it."
}

# Keep the advisory short — a full listing is what the sweep is for. `scope` names where
# the hidden findings are, which differs between one file and a set of them.
function more_findings(hidden, scope) {
    return "…and " hidden " more findings" (scope == "" ? "" : " " scope) "."
}
