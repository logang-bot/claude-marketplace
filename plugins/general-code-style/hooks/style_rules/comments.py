"""Rule 5, the mechanical half: explanatory comments inside a function body.

Only bodies are examined, so a licence banner, a file header, and a doc comment above a
declaration are out of scope by construction. Whether a doc comment states something its
member's name already says is a judgement about the reader, and stays with the reviewer
agent.
"""
from .blocks import iter_functions
from .text import comment_on, is_allowed, marks_for


def body_comments(lines, span, marks):
    """Comment text inside `span` that is neither a directive nor a work marker."""
    found = []
    inside = False
    for index in range(span.start, min(span.end, len(lines))):
        text, inside = comment_on(lines[index], marks, inside)
        if text and not is_allowed(text):
            found.append((index + 1, text))
    return found


def collapse_runs(found):
    """Consecutive comment lines are one comment, so they are reported once."""
    kept = []
    for line, text in found:
        if not kept or line > kept[-1][0] + 1:
            kept.append((line, text))
    return kept


def comment_findings(lines, ext):
    """`(line_number, text)` for every explanatory comment inside a body."""
    marks = marks_for(ext)
    found = []
    for function in iter_functions(lines, ext):
        found += body_comments(lines, function.span, marks)
    return collapse_runs(sorted(found))
