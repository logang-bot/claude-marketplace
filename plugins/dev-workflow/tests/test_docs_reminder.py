#!/usr/bin/env python3
"""Fixtures for the documentation reminder.

Covers the classification the hook makes once git has answered. `changed_files` itself is a
subprocess call and is left to the end-to-end check in docs/testing-and-ci.md.

Run: python3 plugins/dev-workflow/tests/test_docs_reminder.py
"""
import importlib.util
import os
import sys

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, 'hooks',
                    'docs-reminder.py')
FAILURES = []


def load_hook():
    spec = importlib.util.spec_from_file_location('hook', os.path.normpath(HOOK))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(label, actual, expected):
    if actual != expected:
        FAILURES.append(f'{label}: expected {expected!r}, got {actual!r}')


def test_code_without_docs_reminds(hook):
    check('code alone', hook.undocumented_code(['src/Main.kt', 'src/Util.py']),
          ['src/Main.kt', 'src/Util.py'])


def test_docs_alongside_code_is_silent(hook):
    check('doc by extension', hook.undocumented_code(['src/Main.kt', 'README.md']), [])
    check('doc by directory', hook.undocumented_code(['src/Main.kt', 'docs/hooks.adoc']), [])


def test_non_code_is_silent(hook):
    check('config only', hook.undocumented_code(['build.gradle', 'settings.json']), [])
    check('nothing changed', hook.undocumented_code([]), [])


def test_classification(hook):
    check('kotlin is code', hook.is_code('a/B.kt'), True)
    check('markdown is not code', hook.is_code('a/B.md'), False)
    check('anything under docs is a doc', hook.is_doc('docs/x.png'), True)
    check('markdown anywhere is a doc', hook.is_doc('a/B.md'), True)
    check('kotlin is not a doc', hook.is_doc('a/B.kt'), False)


def test_sample_truncates(hook):
    check('four or fewer listed', hook.sample_of(['a', 'b']), 'a, b')
    check('rest counted', hook.sample_of(['a', 'b', 'c', 'd', 'e', 'f']),
          'a, b, c, d (+2 more)')


def main():
    hook = load_hook()
    for name, test in sorted(globals().items()):
        if name.startswith('test_'):
            test(hook)
    for failure in FAILURES:
        print(f'FAIL  {failure}', file=sys.stderr)
    print(f'{"FAILED" if FAILURES else "PASSED"} — {len(FAILURES)} failures')
    return 1 if FAILURES else 0


if __name__ == '__main__':
    sys.exit(main())
