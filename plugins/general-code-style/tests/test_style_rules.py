#!/usr/bin/env python3
"""Fixtures for the general-code-style measurements.

Fixtures live in this file rather than on a command line, and the package is imported
directly rather than shelled out to, per docs/testing-and-ci.md. Both directions matter: a
check that flags everything is as broken as one that flags nothing.

Run: python3 plugins/general-code-style/tests/test_style_rules.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir,
                                'hooks'))

import style_rules as rules  # noqa: E402
from style_rules.sizes import count_parameters  # noqa: E402

FAILURES = []
# Spans both sides of the scope boundary: source files the sweep walks, and the prose, data,
# and binary extensions it does not open.
SAMPLE_EXTS = ('.kt', '.py', '.lua', '.rb', '.tf', '.md', '.json', '.yaml', '.png', '.jar',
               '.txt', '.lock', '')


def lines_of(text):
    return text.strip('\n').splitlines(keepends=True)


def check(label, actual, expected):
    if actual != expected:
        FAILURES.append(f'{label}: expected {expected!r}, got {actual!r}')


def functions(text, ext):
    return list(rules.iter_functions(lines_of(text), ext))


def comments(text, ext):
    return rules.comment_findings(lines_of(text), ext)


BODY = '\n'.join(f'        val step{n} = {n}' for n in range(12))

WRAPPED_KOTLIN = f'''
class Repo {{
    fun wrappedParams(
        alpha: String,
        beta: String,
    ): String {{
{BODY}
        return step1.toString()
    }}
}}
'''

TWO_OFFENDERS = f'''
class Repo {{
    fun first(a: Int) {{
{BODY}
    }}

    fun second(a: Int) {{
{BODY}
    }}
}}
'''

NARRATED_KOTLIN = '''
class Repo {
    fun applyTax(order: Order): Money {
        // step one: get the rate
        val rate = rates.of(order)
        val net = order.net * rate   // adds tax
        return net
    }
}
'''

ALLOWED_KOTLIN = '''
/* Copyright 2026 Someone. Licensed under the MIT licence. */
package com.example

/**
 * Applies the Black-Scholes formula, whose correctness is not evident from the code.
 */
class Repo {
    fun applyTax(order: Order): Money {
        // TODO: round half-even
        // noinspection UnusedVariable
        @Suppress("unused")
        val docs = "see https://example.com/tax#rates"
        return docs.length
    }
}
'''

COMPOSABLE = f'''
@Composable
fun TaxScreen(
    a: String, b: String, c: String, d: String, e: String, f: String
) {{
{BODY}
        // this narration is still a finding
        val extra = 1
}}
'''

BRACE_IN_STRING = '''
class Repo {
    fun render(a: Int): String {
        val opening = "{"
        return opening + a
    }
}
'''

PYTHON = '''
class Repo:
    def apply_tax(self, order, rate, mode):
        """Applies the rate, and this docstring must not count as a body line."""
        step0 = 0
        step1 = 1
        step2 = 2
        step3 = 3
        step4 = 4
        step5 = 5
        step6 = 6
        step7 = 7
        step8 = 8
        step9 = 9
        # narration inside a python body
        return step9

    def small(self, order):
        return order
'''

PYTHON_STAR_ARGS = '''
def call_it(target):
    args = [1, 2]
    return target(
        *args,
    )
'''


def test_wrapped_signature():
    """The regression this work started from: a wrapped signature measured a 0-line body."""
    found = functions(WRAPPED_KOTLIN, '.kt')
    check('wrapped signature is found', len(found), 1)
    check('wrapped body measured', found[0].body, 13)
    check('wrapped params counted', found[0].params, 2)


def test_every_offender_reported():
    warnings = rules.collect_warnings('Repo.kt', lines_of(TWO_OFFENDERS))
    check('both long functions reported', len(warnings), 2)
    check('second one named', 'second' in warnings[1], True)


def test_comment_findings():
    found = comments(NARRATED_KOTLIN, '.kt')
    check('whole-line and trailing narration', len(found), 2)
    check('whole-line narration line', found[0][0], 3)
    check('trailing narration line', found[1][0], 5)


def test_allowed_comments():
    check('directives, markers, banners, urls', comments(ALLOWED_KOTLIN, '.kt'), [])


def test_ui_component_exemption():
    found = functions(COMPOSABLE, '.kt')
    check('composable is yielded', len(found), 1)
    check('composable marked exempt', found[0].ui_exempt, True)
    check('size rules skip it', rules.sized_functions(lines_of(COMPOSABLE), '.kt'), [])
    check('comment rules do not', len(comments(COMPOSABLE, '.kt')), 1)


def test_brace_in_string():
    found = functions(BRACE_IN_STRING, '.kt')
    check('body ends at the real brace', found[0].body, 2)


def test_python_functions():
    found = functions(PYTHON, '.py')
    check('both python defs found', [f.name for f in found], ['apply_tax', 'small'])
    check('docstring not counted', found[0].body, 11)
    check('self not counted as a parameter', found[0].params, 3)
    check('python narration flagged', len(comments(PYTHON, '.py')), 1)


def test_python_star_args_is_not_a_comment():
    check('star-args is code', comments(PYTHON_STAR_ARGS, '.py'), [])


def test_parameter_counting():
    check('trailing comma', count_parameters('a: Int, b: Int, c: Int,', '.kt'), 3)
    check('comparison default', count_parameters('a: Int = if (x < y) 1 else 2, b: Int',
                                                 '.kt'), 2)
    check('generic argument', count_parameters('a: Map<String, Int>, b: Int', '.kt'), 2)
    check('lambda parameter', count_parameters('a: (Int) -> Unit, b: Int', '.kt'), 2)
    check('empty signature', count_parameters('', '.kt'), 0)


def test_file_length():
    over = ['val x = 1\n'] * (rules.FILE_LIMIT + 1)
    check('over the cap', len(rules.collect_warnings('Big.kt', over)), 1)
    check('imports do not count',
          rules.collect_warnings('Big.kt', ['import a.b\n'] * (rules.FILE_LIMIT + 1)), [])


def test_only_source_files_are_measured():
    over = ['a line of prose\n'] * (rules.FILE_LIMIT + 1)
    check('markdown skipped', rules.collect_warnings('README.md', over), [])
    check('json skipped', rules.collect_warnings('data.json', over), [])
    check('resource table skipped', rules.collect_warnings('strings.xml', over), [])
    check('no extension skipped', rules.collect_warnings('LICENSE', over), [])
    check('measured language', len(rules.collect_warnings('Big.kt', over)), 1)
    check('file-only language', len(rules.collect_warnings('big.lua', over)), 1)


def test_hook_and_sweep_share_one_scope():
    over = ['x = 1\n'] * (rules.FILE_LIMIT + 1)
    measured = {ext for ext in SAMPLE_EXTS if rules.collect_warnings(f'big{ext}', over)}
    check('the hook measures exactly the extensions the sweep opens',
          measured, {ext for ext in SAMPLE_EXTS if ext in rules.SOURCE_EXTS})
    check('and that set is not empty', bool(measured), True)


def test_unmeasured_language_is_file_only():
    check('ruby gets no function checks', functions(PYTHON, '.rb'), [])


def main():
    for name, test in sorted(globals().items()):
        if name.startswith('test_'):
            test()
    for failure in FAILURES:
        print(f'FAIL  {failure}', file=sys.stderr)
    print(f'{"FAILED" if FAILURES else "PASSED"} — {len(FAILURES)} failures')
    return 1 if FAILURES else 0


if __name__ == '__main__':
    sys.exit(main())
