"""Measurements: file length, body length, and parameter count."""
from .limits import DECL_SPAN, INDENT_LANGS
from .text import COMMENT, IMPORT, strip_digraphs, strip_strings

RECEIVERS = ('self', 'cls')
TRIPLE = ('"""', "'''")


def measure_file(lines):
    return sum(1 for line in lines if line.strip() and not IMPORT.match(line))


def first_code_line(body):
    return next((i for i, line in enumerate(body) if line.strip()), None)


def opening_quote(body, at):
    """The triple quote the body opens with, or empty when it opens with code."""
    opener = body[at].strip() if at is not None else ''
    return next((quote for quote in TRIPLE if opener.startswith(quote)), '')


def docstring_end(body, ext):
    """Index just past a leading docstring, which documents rather than implements."""
    at = first_code_line(body) if ext in INDENT_LANGS else None
    quote = opening_quote(body, at)
    if not quote:
        return 0
    if body[at].strip() != quote and body[at].strip().endswith(quote):
        return at + 1
    return next((i + 1 for i in range(at + 1, len(body)) if quote in body[i]), len(body))


def measure_body(body, ext):
    """Body size in code lines — blanks, comments, and a docstring do not count."""
    code = body[docstring_end(body, ext):]
    return sum(1 for line in code if line.strip() and not COMMENT.match(line))


def enclosed_by_parens(text, opened):
    depth = 0
    for i in range(opened, len(text)):
        depth += (text[i] == '(') - (text[i] == ')')
        if depth == 0:
            return text[opened + 1:i]
    return ''


def close_of_parens(text, opened):
    """Index just past the `)` that closes the run opened at `opened`, or -1."""
    depth = 0
    for i in range(opened, len(text)):
        depth += (text[i] == '(') - (text[i] == ')')
        if depth == 0:
            return i + 1
    return -1


def declaration_text(lines, start):
    """The declaration at `start`, joined across the lines a signature may wrap over."""
    return strip_strings(''.join(lines[start:start + DECL_SPAN]))


def parameter_text(lines, start):
    """Text between the declaration's parentheses, which may wrap across lines."""
    text = declaration_text(lines, start)
    opened = text.find('(')
    return enclosed_by_parens(text, opened) if opened >= 0 else ''


def angle_depth(generics, previous, char):
    """`<` nests only after an identifier, so a comparison is not read as a generic."""
    if char == '<' and (previous.isalnum() or previous in '_>'):
        return generics + 1
    return generics - 1 if char == '>' and generics else generics


def top_level_commas(text):
    """Commas nested in generics, calls, or collection literals do not separate parameters."""
    depth = generics = count = 0
    for previous, char in zip(' ' + text, text):
        depth += (char in '([{') - (char in ')]}')
        generics = angle_depth(generics, previous, char) if depth == 0 else generics
        count += char == ',' and depth == 0 and generics == 0
    return count


def starts_with_receiver(text):
    return text.lstrip().split(',')[0].strip().split(':')[0].strip() in RECEIVERS


def count_parameters(text, ext):
    """Parameters in a signature. A trailing comma is punctuation, not a parameter."""
    text = strip_digraphs(text).rstrip().rstrip(',')
    if not text.strip():
        return 0
    total = top_level_commas(text) + 1
    implicit = ext in INDENT_LANGS and starts_with_receiver(text)
    return total - 1 if implicit else total
