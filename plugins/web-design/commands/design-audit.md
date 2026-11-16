---
name: design-audit
description: Audits web pages and stylesheets against the web-design rules — a mechanical lint of CSS, HTML, Tailwind and CSS-in-JS for any size of target, plus design-reviewer and ux-reviewer agent reviews of the judgement rules for a diff or a small path. Accepts file paths or a plain-language description of a page or section. Use when asked to check, audit or critique a website's design or UX.
argument-hint: "[path or description] [--dirty] [--lint-only]"
---

Audit `$ARGUMENTS` against the web-design rules. Pick the mode from the size of the target, and
always tell the user which mode you used and what it did not cover.

## 0. Resolve the target

The target is whatever `$ARGUMENTS` names once the flags are removed.

- **Nothing**, or **existing paths**: use them as given and go to step 1.
- **A description** ("the pricing page", "checkout form", "the hero section"): find the files
  first. Start from the route or page that matches, then add the components it renders and the
  stylesheets they import. Stop at shared layout and design-system files unless the description
  is about them. List the files to the user in one line before auditing, so a wrong guess is
  obvious and cheap to correct. If nothing plausible matches, or two areas match equally, ask
  instead of guessing.

When the description names a section inside a larger file (the hero in `Home.tsx`), keep that
section name. The lint works on whole files, so its findings cover all of them; the agents in
step 2 are told which section to focus on.

## 1. Mechanical lint (always)

Find `scripts/audit.sh` inside this plugin by globbing for `**/web-design/scripts/audit.sh` rather
than assuming an install path, then run it:

```
sh <path-to>/audit.sh <path> [...]    # a path, or the files resolved in step 0
sh <path-to>/audit.sh --dirty         # no path: the uncommitted working tree
```

It covers the measurable rules: contrast, weights, sizes, line-height, measure, justification,
named and pure-black colours, palette sprawl, type scale, shadow darkness, spacing and radius
scales, animation durations, link underlines, vague CTA text, mixed icon packs, raster icons, and
mismatched side-by-side images. The scales come from DESIGN.md when it defines them, and rules it
lists under `relax` are not reported (the audit prints which).

## 2. Judgement review (diffs and small targets)

Count the pages, components and stylesheets in the target.

- **No path, or 30 files or fewer, and no `--lint-only`:** launch the `design-reviewer` agent
  (visual design, areas 01–08) on the target. If the target contains markup or components (not
  only stylesheets), also launch the `ux-reviewer` agent (UX and layout, areas 09–10). Run them in
  parallel. Both are read-only. If step 0 resolved a section inside a larger file, tell both agents
  to focus on that section.
- **More than 30 files, or `--lint-only`:** skip the agents. Say that the judgement rules were not
  reviewed, and suggest narrowing to a page or a directory.

## 3. Report

Merge the results into one report: the most severe findings first, then grouped by file, with
mechanical and judgement findings labelled by rule ID. Finish with the one-line personality
verdict from `design-reviewer` and the five-second verdict from `ux-reviewer`, when they ran.

Do not fix anything unless the user asks. If they do, fix in severity order and re-run step 1 to
confirm.
