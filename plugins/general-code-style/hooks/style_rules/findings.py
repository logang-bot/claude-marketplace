"""The advisory text for each kind of finding, and the cap on how much of it is shown."""
from .limits import FILE_LIMIT, FUNCTION_LIMIT, MAX_WARNINGS, PARAM_LIMIT


def file_warning(path, code_lines):
    if code_lines <= FILE_LIMIT:
        return None
    return (f'{path} is {code_lines} lines excluding imports (cap is ~200, {FILE_LIMIT} '
            f'with spare). Split it into child classes or files with focused '
            f'responsibilities.')


def length_warning(path, function):
    return (f'{path}:{function.line} function `{function.name}` has a {function.body}-line '
            f'body (cap is ~7, {FUNCTION_LIMIT} with spare). Extract the steps into named '
            f'helpers.')


def parameter_warning(path, function):
    return (f'{path}:{function.line} function `{function.name}` takes {function.params} '
            f'parameters (max is {PARAM_LIMIT}). Group the related extras into a data '
            f'class, or the equivalent record, struct, or interface.')


def comment_warning(path, finding):
    line, text = finding
    return (f'{path}:{line} explains code with a comment — `{text[:60]}`. Rename the value '
            f'or extract a named helper so the code says it; only a tool directive, a '
            f'TODO/FIXME, or doc-comment on non-obvious math belongs here.')


def cap(found):
    """Keep the advisory short — a full listing is what the sweep is for."""
    if len(found) <= MAX_WARNINGS:
        return found
    hidden = len(found) - MAX_WARNINGS
    return found[:MAX_WARNINGS] + [f'…and {hidden} more findings in this file.']
