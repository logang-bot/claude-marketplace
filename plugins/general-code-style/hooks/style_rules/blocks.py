"""Finding declarations and the span of the body each one opens.

Two strategies, chosen by extension: brace matching for C-family syntax, indentation for
Python. A declaration whose body cannot be located is skipped rather than guessed at, so an
expression body (`fun total() = a + b`) is never measured as an empty one.
"""
import re
from collections import namedtuple

from .limits import BRACE_LANGS, DECL_SPAN, INDENT_LANGS
from .sizes import close_of_parens, count_parameters, measure_body, parameter_text
from .text import strip_strings

# A declaration that opens a body. Requires a real declaration keyword or an access
# modifier, so that trailing-lambda calls (`Column(...) {`, `items(...) {`) are not
# mistaken for functions.
DECL = re.compile(
    r'^\s*(?:(?:public|private|protected|internal|open|final|static|abstract|override|'
    r'suspend|inline|operator|infix|tailrec|async|export|default)\s+)*'
    r'(?:fun|func|fn|def|function)\s+(\w+)\s*[<(]'
)
# Java / C# / C++ style: modifiers, then a return type, then the name. No keyword to key on,
# so an access modifier or `static` is required to keep the match honest.
DECL_TYPED = re.compile(
    r'^\s*(?:(?:public|private|protected|internal|static|final|abstract|override|virtual|'
    r'synchronized|native)\s+)+[\w<>\[\],.?\s]+?\b(\w+)\s*\([^;]*\)[\w\s,]*\{\s*$'
)
KEYWORD_LANGS = {'.kt', '.kts', '.swift', '.go', '.rs', '.js', '.jsx', '.ts', '.tsx',
                 '.php', '.scala', '.dart', '.gradle', '.groovy'}
UI_MARKERS = ('@Composable', '@Preview', 'React.FC', ': FC<', 'some View')

Span = namedtuple('Span', 'start end')
Function = namedtuple('Function', 'name line body params ui_exempt span')


def declaration_at(line, ext):
    match = DECL.match(line)
    if match:
        return match.group(1)
    if ext not in KEYWORD_LANGS:
        match = DECL_TYPED.match(line)
        if match:
            return match.group(1)
    return None


def body_start(lines, start):
    """Line index holding the `{` that opens the body, or None for an expression body."""
    text = strip_strings(''.join(lines[start:start + DECL_SPAN]))
    after = close_of_parens(text, text.find('(')) if '(' in text else -1
    brace = text.find('{', after) if after >= 0 else -1
    return start + text.count('\n', 0, brace) if brace >= 0 else None


def end_of_block(lines, start):
    """Index of the line closing the block that opens at `start`, or None."""
    depth = 0
    for j in range(start, len(lines)):
        bare = strip_strings(lines[j])
        depth += bare.count('{') - bare.count('}')
        if depth <= 0 and (j > start or '}' in bare):
            return j
    return None


def indent_of(line):
    return len(line) - len(line.lstrip())


def indent_block_end(lines, start):
    """Last line index of the indented body headed by `start`."""
    header = indent_of(lines[start])
    last = start
    for j in range(start + 1, len(lines)):
        if not lines[j].strip():
            continue
        if indent_of(lines[j]) <= header:
            return last
        last = j
    return last


def brace_span(lines, start):
    opened = body_start(lines, start)
    closed = end_of_block(lines, opened) if opened is not None else None
    return Span(opened + 1, closed) if closed is not None else None


def body_span(lines, start, ext):
    """Slice bounds of the body opened by the declaration at `start`, or None."""
    if ext in INDENT_LANGS:
        return Span(start + 1, indent_block_end(lines, start) + 1)
    return brace_span(lines, start)


def is_ui_component(lines, start):
    context = ''.join(lines[max(0, start - 4):start + 1])
    return any(marker in context for marker in UI_MARKERS)


def function_at(lines, start, ext):
    """The function declared at `start`, or None if no measurable one is."""
    name = declaration_at(lines[start], ext)
    span = body_span(lines, start, ext) if name else None
    if span is None:
        return None
    return Function(name, start + 1, measure_body(lines[span.start:span.end], ext),
                    count_parameters(parameter_text(lines, start), ext),
                    is_ui_component(lines, start), span)


def iter_functions(lines, ext):
    """Yield a `Function` per declaration, jumping past each body so helpers nested inside
    another function are not double-counted. UI components are yielded with `ui_exempt`
    set — the size rules skip them, the comment rules do not."""
    if ext not in BRACE_LANGS | INDENT_LANGS:
        return
    i = 0
    while i < len(lines):
        found = function_at(lines, i, ext)
        if found:
            yield found
        i = max(found.span.end, i + 1) if found else i + 1
