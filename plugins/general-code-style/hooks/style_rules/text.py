"""Line-level text handling shared by the measurements.

Every rule here has to survive punctuation that only looks like syntax: a brace inside a
string, a `//` inside a URL, a `<` that is a comparison rather than a generic.
"""
import re

from .limits import INDENT_LANGS

IMPORT = re.compile(r'^\s*(import|package|using|#include|from\s+\S+\s+import)\b')
COMMENT = re.compile(r'^\s*(//|#|\*|/\*)')
# Digraphs whose angle bracket is not generic nesting: lambda arrows and comparisons.
ARROWS = ('->', '=>', '>=', '<=')
# Text that is not explanation, so it is never a comment finding.
DIRECTIVES = ('noinspection', 'eslint-disable', 'ts-ignore', 'ts-expect-error',
              'prettier-ignore', 'pragma', 'noqa', 'pylint:', 'mypy:', 'type:', 'fmt:',
              'swiftlint:', 'checkstyle', 'nosonar', 'nolint', 'suppress', 'formatter',
              'region', 'endregion', 'todo', 'fixme', 'hack', 'xxx', 'license',
              'licence', 'copyright')


def scan_char(char, quote, escaped):
    """Advance the literal scanner one character. Returns `(quote, escaped, keep)`."""
    if escaped:
        return quote, False, not quote
    if char == '\\':
        return quote, True, not quote
    if quote:
        return ('' if char == quote else quote), False, False
    return ('' if char not in '"\'' else char), False, char not in '"\''


def strip_strings(line):
    """Blank out string-literal contents, keeping every index in place."""
    out = []
    quote = ''
    escaped = False
    for char in line:
        quote, escaped, keep = scan_char(char, quote, escaped)
        out.append(char if keep else ' ')
    return ''.join(out)


def strip_digraphs(text):
    for arrow in ARROWS:
        text = text.replace(arrow, '')
    return text


def marks_for(ext):
    """The markers that actually open a comment in this language."""
    return ('#',) if ext in INDENT_LANGS else ('//', '/*')


def is_allowed(comment):
    """Tool directives, work markers, and licence banners are not explanation."""
    lowered = comment.lstrip('/#*!<> \t').lower()
    return not lowered or any(lowered.startswith(word) for word in DIRECTIVES)


def comment_in(line, marks):
    """The comment opening on `line`, whole-line or trailing, or `''` if there is none."""
    bare = strip_strings(line)
    starts = [bare.find(mark) for mark in marks]
    at = min([start for start in starts if start >= 0], default=-1)
    return line[at:].strip() if at >= 0 else ''


def comment_on(line, marks, inside):
    """The comment text on this line, and whether a block comment is still open after it."""
    if inside:
        return line.strip(), '*/' not in line
    text = comment_in(line, marks)
    return text, text.startswith('/*') and '*/' not in text
