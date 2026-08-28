"""Style-rule measurements shared by the size hook, the sweep script, and the tests.

Public surface — the hook, `scripts/sweep.py`, and `tests/test_style_rules.py` all import
from here, which is what stops any two of them disagreeing about a cap:

    FILE_LIMIT, FUNCTION_LIMIT, PARAM_LIMIT, MEASURED_LANGS, SOURCE_EXTS
    measure_file(lines)             -> code lines, imports excluded
    iter_functions(lines, ext)      -> Function(name, line, body, params, ui_exempt, span)
    comment_findings(lines, ext)    -> [(line_number, text)]
    collect_warnings(path, lines)   -> [advisory text]
"""
import os

from .blocks import Function, iter_functions
from .comments import comment_findings
from .findings import cap, comment_warning, file_warning, length_warning, parameter_warning
from .limits import (FILE_LIMIT, FUNCTION_LIMIT, MAX_WARNINGS, MEASURED_LANGS, PARAM_LIMIT,
                     SOURCE_EXTS)
from .sizes import measure_file

__all__ = ['FILE_LIMIT', 'FUNCTION_LIMIT', 'PARAM_LIMIT', 'MAX_WARNINGS', 'MEASURED_LANGS',
           'SOURCE_EXTS', 'Function', 'measure_file', 'iter_functions', 'comment_findings',
           'collect_warnings', 'sized_functions']


def file_length_warning(path, lines, ext):
    """Only source files are measured, which is the same scope the sweep walks."""
    if ext not in SOURCE_EXTS:
        return None
    return file_warning(path, measure_file(lines))


def sized_functions(lines, ext):
    """The functions the size rules apply to — UI components are exempt from those two."""
    return [found for found in iter_functions(lines, ext) if not found.ui_exempt]


def size_warnings(path, lines, ext):
    """Body-length and parameter advisories for every function over a cap, not just one."""
    sized = sized_functions(lines, ext)
    return ([length_warning(path, f) for f in sized if f.body > FUNCTION_LIMIT]
            + [parameter_warning(path, f) for f in sized if f.params > PARAM_LIMIT])


def collect_warnings(path, lines):
    """Every advisory the size and comment rules raise for one file."""
    ext = os.path.splitext(path)[1]
    found = [file_length_warning(path, lines, ext)]
    found += size_warnings(path, lines, ext)
    found += [comment_warning(path, c) for c in comment_findings(lines, ext)]
    return cap([warning for warning in found if warning])
