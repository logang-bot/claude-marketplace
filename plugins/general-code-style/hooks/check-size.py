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

FILE_LIMIT = 250          # 200 target + 50 spare
FUNCTION_LIMIT = 15       # 10 target + 5 spare

IMPORT = re.compile(r'^\s*(import|package|using|#include|from\s+\S+\s+import)\b')
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


def extent(lines, start):
    """Body line count and end index for the block opening at `start`, or None."""
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth <= 0 and j > start:
            return j - start - 1, j
        if depth <= 0 and j == start and '}' in lines[j]:
            return 0, j
    return None


def measure_functions(lines, ext):
    """Return (name, line_number, body_lines) for the longest top-level function.

    Nested declarations are skipped by jumping past each function once measured, so a
    helper declared inside another function is not double-counted.
    """
    worst = None
    i = 0
    while i < len(lines):
        name = declaration_at(lines[i], ext)
        if not name:
            i += 1
            continue
        span = extent(lines, i)
        if span is None:
            i += 1
            continue
        body, end = span
        # UI component functions are exempt from the length rule.
        context = ''.join(lines[max(0, i - 4):i + 1])
        exempt = any(marker in context for marker in UI_MARKERS)
        if not exempt and (worst is None or body > worst[2]):
            worst = (name, i + 1, body)
        i = end + 1
    return worst


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    path = (payload.get('tool_input') or {}).get('file_path')
    if not path or not os.path.isfile(path):
        return 0

    ext = os.path.splitext(path)[1]
    try:
        with open(path, encoding='utf-8', errors='replace') as handle:
            lines = handle.readlines()
    except OSError:
        return 0

    warnings = []
    code_lines = measure_file(lines)
    if code_lines > FILE_LIMIT:
        warnings.append(
            f'{path} is {code_lines} lines excluding imports (cap is ~200, {FILE_LIMIT} '
            f'with spare). Split it into child classes or files with focused '
            f'responsibilities.'
        )

    if ext in BRACE_LANGS:
        worst = measure_functions(lines, ext)
        if worst and worst[2] > FUNCTION_LIMIT:
            name, start, body = worst
            warnings.append(
                f'{path}:{start} function `{name}` has a {body}-line body (cap is ~10, '
                f'{FUNCTION_LIMIT} with spare). Extract the steps into named helpers.'
            )

    if not warnings:
        return 0

    print('Style advisory (general-code-style) — the write succeeded; consider addressing '
          'this before moving on:\n- ' + '\n- '.join(warnings), file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())
