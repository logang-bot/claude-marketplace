#!/usr/bin/env python3
"""PostToolUse hook: warn when a written file or function exceeds the style caps.

Reads the hook payload on stdin, measures the file that was just written, and exits 2
with an advisory message on stderr when a cap is exceeded. Exit 2 is what surfaces the
message to Claude; the wording makes clear it is advice, not a blocked action.
"""
import json
import os
import re
import sys
from collections import namedtuple

FILE_LIMIT = 250          # 200 target + 50 spare
FUNCTION_LIMIT = 10       # 7 target + 3 spare
PARAM_LIMIT = 3

IMPORT = re.compile(r'^\s*(import|package|using|#include|from\s+\S+\s+import)\b')
COMMENT = re.compile(r'^\s*(//|#|\*|/\*)')
BRACE_LANGS = {'.kt', '.java', '.js', '.jsx', '.ts', '.tsx', '.swift', '.c', '.cc',
               '.cpp', '.h', '.hpp', '.cs', '.go', '.rs', '.scala', '.php'}
# A declaration that opens a body on the same line. Requires a real declaration keyword
# or an access modifier, so that trailing-lambda calls (`Column(...) {`, `items(...) {`)
# are not mistaken for functions.
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
KEYWORD_LANGS = {'.kt', '.swift', '.go', '.rs', '.js', '.jsx', '.ts', '.tsx', '.php', '.scala'}
UI_MARKERS = ('@Composable', '@Preview', 'React.FC', ': FC<', 'some View')
# Digraphs whose angle bracket is not generic nesting: lambda arrows and comparisons.
ARROWS = ('->', '=>', '>=', '<=')
DECL_SPAN = 12            # lines a parameter list may wrap across before we give up

Span = namedtuple('Span', 'start end')


def declaration_at(line, ext):
    match = DECL.match(line)
    if match:
        return match.group(1)
    if ext not in KEYWORD_LANGS:
        match = DECL_TYPED.match(line)
        if match:
            return match.group(1)
    return None


def measure_file(lines):
    return sum(1 for line in lines if line.strip() and not IMPORT.match(line))


def measure_body(body):
    """Body size in code lines — blanks and comments do not count toward the cap."""
    return sum(1 for line in body if line.strip() and not COMMENT.match(line))


def end_of_block(lines, start):
    """Index of the line closing the block that opens at `start`, or None."""
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth <= 0 and j > start:
            return j
        if depth <= 0 and j == start and '}' in lines[j]:
            return j
    return None


def enclosed_by_parens(text, opened):
    depth = 0
    for i in range(opened, len(text)):
        depth += (text[i] == '(') - (text[i] == ')')
        if depth == 0:
            return text[opened + 1:i]
    return ''


def parameter_text(lines, start):
    """Text between the declaration's parentheses, which may wrap across lines."""
    text = ''.join(lines[start:start + DECL_SPAN])
    opened = text.find('(')
    return enclosed_by_parens(text, opened) if opened >= 0 else ''


def strip_digraphs(text):
    for arrow in ARROWS:
        text = text.replace(arrow, '')
    return text


def top_level_commas(text):
    """Commas nested in generics, calls, or collection literals do not separate parameters."""
    depth = 0
    count = 0
    for char in text:
        depth += char in '(<['
        depth -= char in ')>]'
        count += char == ',' and depth == 0
    return count


def count_parameters(text):
    text = strip_digraphs(text)
    return top_level_commas(text) + 1 if text.strip() else 0


def is_ui_component(lines, start):
    context = ''.join(lines[max(0, start - 4):start + 1])
    return any(marker in context for marker in UI_MARKERS)


def function_record(lines, span, name):
    return (name, span.start + 1, measure_body(lines[span.start + 1:span.end]),
            count_parameters(parameter_text(lines, span.start)))


def iter_functions(lines, ext):
    """Yield `(name, line_number, body_lines, parameters)` for each top-level function.

    Nested declarations are skipped by jumping past each function once measured, so a
    helper declared inside another function is not double-counted. UI component
    functions are exempt from both size rules and are not yielded at all.
    """
    i = 0
    while i < len(lines):
        name = declaration_at(lines[i], ext)
        end = end_of_block(lines, i) if name else None
        if end is None:
            i += 1
            continue
        if not is_ui_component(lines, i):
            yield function_record(lines, Span(i, end), name)
        i = end + 1


def measure_functions(lines, ext):
    """The worst body-length and worst parameter-count offenders, or None for each."""
    longest = widest = None
    for record in iter_functions(lines, ext):
        if longest is None or record[2] > longest[2]:
            longest = record
        if widest is None or record[3] > widest[3]:
            widest = record
    return longest, widest


def file_warning(path, lines):
    code_lines = measure_file(lines)
    if code_lines <= FILE_LIMIT:
        return None
    return (f'{path} is {code_lines} lines excluding imports (cap is ~200, {FILE_LIMIT} '
            f'with spare). Split it into child classes or files with focused '
            f'responsibilities.')


def length_warning(path, longest):
    if not longest or longest[2] <= FUNCTION_LIMIT:
        return None
    name, start, body, _ = longest
    return (f'{path}:{start} function `{name}` has a {body}-line body (cap is ~7, '
            f'{FUNCTION_LIMIT} with spare). Extract the steps into named helpers.')


def parameter_warning(path, widest):
    if not widest or widest[3] <= PARAM_LIMIT:
        return None
    name, start, _, params = widest
    return (f'{path}:{start} function `{name}` takes {params} parameters (max is '
            f'{PARAM_LIMIT}). Group the related extras into a data class, or the '
            f'equivalent record, struct, or interface.')


def collect_warnings(path, lines):
    ext = os.path.splitext(path)[1]
    found = [file_warning(path, lines)]
    if ext in BRACE_LANGS:
        longest, widest = measure_functions(lines, ext)
        found += [length_warning(path, longest), parameter_warning(path, widest)]
    return [warning for warning in found if warning]


def read_payload():
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return None


def payload_path(payload):
    path = (payload.get('tool_input') or {}).get('file_path')
    return path if path and os.path.isfile(path) else None


def target_lines(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as handle:
            return handle.readlines()
    except OSError:
        return None


def advise(warnings):
    print('Style advisory (general-code-style) — the write succeeded; consider addressing '
          'this before moving on:\n- ' + '\n- '.join(warnings), file=sys.stderr)
    return 2


def main():
    payload = read_payload()
    path = payload_path(payload) if payload else None
    lines = target_lines(path) if path else None
    if lines is None:
        return 0
    warnings = collect_warnings(path, lines)
    return advise(warnings) if warnings else 0


if __name__ == '__main__':
    sys.exit(main())
