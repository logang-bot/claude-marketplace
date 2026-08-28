#!/usr/bin/env python3
"""Measure a whole tree against the general-code-style rules.

Loads the limits and the measurement functions from `hooks/style_rules/` rather than
restating them, so a sweep and a post-write advisory can never disagree about a cap.

Reports rules 1-3 and the mechanical half of rule 5 — comments that explain code inside a
function body. Naming, and whether a doc comment says something its member's name already
says, need judgement about what a reader would misunderstand: that is the style-reviewer
agent's job, not a script's.
"""
import argparse
import os
import subprocess
import sys
from collections import namedtuple

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir,
                                'hooks'))

import style_rules as rules  # noqa: E402

SKIP_DIRS = {'.git', '.gradle', '.idea', '__pycache__', 'node_modules', 'build',
             'dist', 'out', 'target', 'venv', '.venv', 'Pods', 'vendor'}
SOURCE_EXTS = rules.SOURCE_EXTS
Finding = namedtuple('Finding', 'path lines long wide narrated')
Sweep = namedtuple('Sweep', 'findings scanned root top')


def tracked_files(root):
    """Files git knows about, so .gitignore is respected for free. None if not a repo."""
    try:
        done = subprocess.run(['git', '-C', root, 'ls-files', '-z'],
                              capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    return None if done.returncode != 0 else [os.path.join(root, name)
                                              for name in done.stdout.split('\0') if name]


def walked_files(root):
    found = []
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        found.extend(os.path.join(base, name) for name in names)
    return found


def in_skipped_dir(path):
    return any(part in SKIP_DIRS for part in path.split(os.sep))


def source_files(root):
    if os.path.isfile(root):
        return [root]
    found = tracked_files(root)
    if found is None:
        found = walked_files(root)
    return sorted(f for f in found
                  if os.path.splitext(f)[1] in SOURCE_EXTS and not in_skipped_dir(f))


def read_lines(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as handle:
            return handle.readlines()
    except OSError:
        return None


def scan_file(path):
    lines = read_lines(path)
    if lines is None:
        return None
    ext = os.path.splitext(path)[1]
    found = rules.sized_functions(lines, ext)
    return Finding(path=path, lines=rules.measure_file(lines),
                   long=[f for f in found if f.body > rules.FUNCTION_LIMIT],
                   wide=[f for f in found if f.params > rules.PARAM_LIMIT],
                   narrated=rules.comment_findings(lines, ext))


def flagged(finding):
    return (finding.lines > rules.FILE_LIMIT or finding.long or finding.wide
            or finding.narrated)


def severity(finding):
    """Rank structural problems first, then the worst body, then the widest signature."""
    return (max(0, finding.lines - rules.FILE_LIMIT),
            max((f.body for f in finding.long), default=0),
            max((f.params for f in finding.wide), default=0),
            len(finding.narrated))


def totals(findings):
    return (sum(1 for f in findings if f.lines > rules.FILE_LIMIT),
            sum(len(f.long) for f in findings),
            sum(len(f.wide) for f in findings),
            sum(len(f.narrated) for f in findings))


def describe(finding, base):
    parts = ['%d lines' % finding.lines] if finding.lines > rules.FILE_LIMIT else []
    parts += [f'{f.name}() {f.body}-line body at :{f.line}' for f in finding.long]
    parts += [f'{f.name}() {f.params} params at :{f.line}' for f in finding.wide]
    parts += [f'comment at :{line}' for line, _ in finding.narrated]
    return f'{os.path.relpath(finding.path, base)}  ·  ' + ' · '.join(parts)


def relative_base(root):
    return (os.path.dirname(root) or '.') if os.path.isfile(root) else root


def summary_lines(sweep):
    over, long_fns, wide_fns, narrated = totals(sweep.findings)
    return [f'Swept {sweep.scanned} files in {sweep.root} · size, parameter, and in-body '
            f'comment rules (naming not evaluated)', '',
            f'  {over} files over the {rules.FILE_LIMIT}-line cap',
            f'  {long_fns} functions over the {rules.FUNCTION_LIMIT}-line body cap',
            f'  {wide_fns} signatures over {rules.PARAM_LIMIT} parameters',
            f'  {narrated} comments explaining code inside a body']


def listing_lines(sweep):
    base = relative_base(sweep.root)
    shown = sweep.findings[:sweep.top]
    out = ['', f'Worst {len(shown)} of {len(sweep.findings)} files with findings:', '']
    out += ['  ' + describe(finding, base) for finding in shown]
    if len(sweep.findings) > sweep.top:
        out += ['', f'  {len(sweep.findings) - sweep.top} more files with findings — '
                    f're-run after fixing these.']
    return out


def render(sweep):
    out = summary_lines(sweep)
    if not sweep.findings:
        return '\n'.join(out + ['', 'Nothing over the caps.'])
    return '\n'.join(out + listing_lines(sweep))


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('path', nargs='?', default='.')
    parser.add_argument('--top', type=int, default=20, help='files to list (default 20)')
    parser.add_argument('--strict', action='store_true', help='exit 1 when anything is found')
    return parser.parse_args()


def collect(paths):
    found = [scan_file(path) for path in paths]
    return sorted((f for f in found if f and flagged(f)), key=severity, reverse=True)


def main():
    args = parse_args()
    root = os.path.normpath(args.path)
    if not os.path.exists(root):
        print(f'sweep: no such path: {root}', file=sys.stderr)
        return 2
    paths = source_files(root)
    findings = collect(paths)
    print(render(Sweep(findings, len(paths), root, args.top)))
    return 1 if (args.strict and findings) else 0


if __name__ == '__main__':
    sys.exit(main())
