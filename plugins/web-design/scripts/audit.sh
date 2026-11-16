#!/bin/sh
# Lint pages and stylesheets against the web-design rules, with no model involved.
#
# Runs exactly the extractors and checks the hooks run, loaded from hooks/lib/, so an audit and a
# post-write advisory can never disagree. It covers the measurable rules only; the judgement
# rules are the design-reviewer and ux-reviewer agents' job, which /design-audit combines.
#
# Usage: audit.sh [path ...] [--dirty] [--top N] [--strict]
#
#   path      files or directories (default: the current directory). In a git repository a
#             directory is listed with git, so ignored files stay out.
#   --dirty   only web files that differ from HEAD or are untracked
#   --top N   show at most N findings groups (default: all)
#   --strict  exit 1 when there are findings, for use as a pre-commit gate
#
# Cross-file checks (more than two font families, mixed icon packs) apply across everything
# audited in one run, so auditing a whole app is what answers "how many typefaces do we use".

set -u
ENGINE_LIB=${ENGINE_LIB:-$(dirname "$0")/../hooks/lib}
. "$ENGINE_LIB/engine.sh"
. "$ENGINE_LIB/state.sh"
. "$ENGINE_LIB/brief.sh"
require_tools awk

TOP=0
STRICT=0
DIRTY=0
TARGETS=""
while [ $# -gt 0 ]; do
    case $1 in
        --top) TOP=$2; shift 2 ;;
        --strict) STRICT=1; shift ;;
        --dirty) DIRTY=1; shift ;;
        *) TARGETS="$TARGETS
$1"; shift ;;
    esac
done
[ -n "$TARGETS" ] || TARGETS=.

list_target() {
    if [ -f "$1" ]; then
        printf '%s\n' "$1"
    elif git -C "$1" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$1" ls-files -co --exclude-standard 2>/dev/null | awk -v d="$1" 'NF { print d "/" $0 }'
    else
        find "$1" -name node_modules -prune -o -type f -print 2>/dev/null
    fi
}

first=$(printf '%s\n' "$TARGETS" | awk 'NF { print; exit }')
[ -d "$first" ] || first=$(dirname "$first")
root=$(project_root "$first")

if [ "$DIRTY" = 1 ]; then
    files=$(turn_candidates "$root")
else
    files=$(printf '%s\n' "$TARGETS" | while IFS= read -r t; do
        [ -n "$t" ] || continue
        list_target "$t"
    done | web_filter | awk '!seen[$0]++')
fi

if [ -z "$files" ]; then
    printf '%s\n' "web-design audit: no pages or stylesheets found."
    exit 0
fi

# Rules the brief switches off are not reported, so say which ones, or a clean audit could be
# mistaken for a clean bill of health. Contrast and body-text size cannot be switched off.
brief=$(brief_file "$root") || brief=""
relax_note=""
if [ -n "$brief" ]; then
    relaxed=$(brief_value "$brief" relax | tr -c 'A-Za-z0-9\n-' ' ' | tr 'a-z' 'A-Z' | awk '{
        for (i = 1; i <= NF; i++) { if ($i == "COLOR-11" || $i == "TYPO-05") bad = bad (bad ? ", " : "") $i; else ok = ok (ok ? ", " : "") $i }
    } END { print ok "|" bad }')
    [ -n "${relaxed%%|*}" ] && relax_note="Relaxed by DESIGN.md (not reported): ${relaxed%%|*}"
    if [ -n "${relaxed#*|}" ]; then
        relax_note="${relax_note:+$relax_note
}DESIGN.md lists ${relaxed#*|}, which cannot be relaxed; still reported."
    fi
fi

findings=$(printf '%s\n' "$files" | lint_files "$root")
count=$(printf '%s\n' "$files" | grep -c .)
if [ -z "$findings" ]; then
    printf '%s\n' "web-design audit: $count file(s) checked, no findings."
    [ -n "$relax_note" ] && printf '%s\n' "$relax_note"
    exit 0
fi

printf '%s\n' "$findings" | awk -f "$ENGINE_LIB/report.awk" -v mode=audit -v root="$root" -v limit="$TOP"
printf '%s\n' "($count file(s) checked. Measurable rules only — hierarchy, imagery, copy and personality fit need /design-audit.)"
[ -n "$relax_note" ] && printf '%s\n' "$relax_note"
[ "$STRICT" = 1 ] && exit 1
exit 0
