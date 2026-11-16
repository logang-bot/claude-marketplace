# `web-design`

Web design rules for building websites and web app screens: typography, colour, images, icons,
shadows, border-radius, whitespace, visual hierarchy, user experience, and layout. Every one of
them follows from a **website personality**, chosen first and recorded in the project's
`DESIGN.md`.

**Install it** in any project that builds web front ends. It stays quiet elsewhere: subagent
injection is gated on the project containing markup or stylesheets, and the write-time hooks only
fire for web files.

## How the pieces fit together

| Piece | What it is | How it runs |
|---|---|---|
| **Commands** (2) | The things you run: `/design-brief` decides the design, `/design-audit` checks code against it | You type them, with arguments |
| **Skills** (11) | The rules themselves, one skill per design area | Automatically, when a task matches; or by hand as `/web-design:<skill>` |
| **Agents** (2) | Read-only reviewers for the rules a script cannot judge | Started by `/design-audit`, or when you ask for a design or UX review |
| **Hooks** (6) | Put the rules in front of Claude before it writes UI code, and lint what it wrote | On their own, at fixed points in every session |
| **Script** | `scripts/audit.sh`, the linter | Via `/design-audit` and the agents, or from your shell |

Day to day you only touch the two commands and ordinary requests ("build the pricing page"). The
hooks make sure the rules are applied whether or not a skill was loaded.

**Commands take arguments, skills normally do not.** Whatever follows a command's name reaches its
instructions (`/design-audit the pricing page --lint-only`). Skills load on their own when a task
matches their description. Calling one by hand is allowed and useful when you want one area's full
guidance on purpose (`/web-design:building-color-palettes` before reworking a theme), but text
after a skill's name is only extra context: none of these skills reads arguments.

Rule IDs combine an area and a number, so `TYPO-08` is typography rule 8 in the
`setting-typography` skill. Findings, skills and agent reports all use the same IDs.

## Use cases

| I want to… | Use |
|---|---|
| Start a new web app or site from scratch | `/design-brief` → plan → build → `/design-audit` per page |
| Revise or clean up an existing project | `/design-audit --lint-only` (whole project) → `/design-brief` → `/design-audit <page>` per page |
| Add a page or feature to a project that already has a brief | Just ask; then `/design-audit <the new page>` |
| Review one page, section or component | `/design-audit the checkout form` (plain words or a path) |
| Check my uncommitted work before committing | `/design-audit` with no arguments (or `--dirty`) |
| Get a fast health check, or track progress over time | `/design-audit <path> --lint-only` |
| Change the design direction (rebrand, new personality) | `/design-brief` (update) → re-apply tokens → `/design-audit --lint-only` |
| Write down the design an existing project already uses | `/design-brief` |
| Use a style that fits none of the seven personalities | `/design-brief "neo-brutalist, mono type, hard shadows"` → normal workflow |
| Keep an existing project's own style, which fits none of the seven | `/design-audit src --lint-only` → `/design-brief custom` → normal workflow |
| Review only the copy, CTAs and page structure | Ask for a UX review of the page (starts `ux-reviewer`) |
| Fix contrast and legibility across a project | `/design-audit <path> --lint-only`, then ask to fix `COLOR-11`, `TYPO-05`, `TYPO-08` findings |
| Go deep on one design area | Call the skill by hand, e.g. `/web-design:setting-typography` |
| Stop design regressions from being committed | `scripts/audit.sh --dirty --strict` as a pre-commit hook |

### Start a new web app from scratch

1. **`/design-brief`.** (If you skip it and just ask for a page, Claude asks first whether to run
   it or decide the style itself.) Answer one short round of questions about what the site is for,
   who it is for, and how it should feel. An empty project has nothing to infer from, so you will be asked.
   Claude recommends a personality and writes `DESIGN.md` with its tokens: typefaces, type scale,
   palette, spacing scale, radius, shadows, icon pack. Do this first; every later check reads it.
2. **Plan in plan mode** (optional, recommended), e.g. "plan the landing page and the app shell".
   The prompt hook adds the full rules to the planning turn, so the plan fixes the personality and
   tokens up front.
3. **Build the foundation before any page.** Ask Claude to turn `DESIGN.md` into code: `:root`
   custom properties, the Tailwind theme, or a theme object. Pages built only from those tokens
   rarely trip the colour, type-scale or spacing checks.
4. **Build page by page.** After each batch of writes, the hook reports what the write introduced
   and Claude fixes it on the spot, or keeps a deliberate choice and says why.
5. **`/design-audit <the page>` after each page or milestone.** This adds the two reviewer agents:
   hierarchy, CTA prominence, imagery, copy and personality fit, which no script can judge.

### Revise an existing project

The hooks only report what a request introduces, so the problems already in the project stay
invisible until you ask for them. Start from a measurement, not from a request.

1. **`/design-audit src --lint-only`.** A baseline of the whole project: which rules, how many,
   where, worst first. It is fast and deterministic, and the agents could not read a whole project
   well anyway.
2. **`/design-brief`.** Claude reads the codebase first and may ask fewer questions, or none.
   Decide whether to keep the personality (the brief then records the design in use) or to set a
   new direction. Once `font-families`, `icon-pack` and `spacing-scale` are filled in, fonts, packs
   and spacing that disagree with them are flagged.
3. **Consolidate the tokens.** Move the palette, type scale and spacing scale into custom
   properties or the theme, and point the existing styles at them. This usually clears most
   colour, font-size and spacing findings at once.
4. **Page by page, most important first:** `/design-audit the pricing page`, then "fix these, most
   severe first". The command re-runs the lint to confirm.
5. **Re-run the step 1 baseline** now and then to track progress.

Note that when Claude edits a file, the hooks only report findings on the lines that edit wrote. A
request like "fix the typography" on an old file will not surface the rest of its problems on its
own: that is what `/design-audit` is for.

### A style outside the seven personalities

The seven personalities are starting points, not a boundary. Two situations fall outside them:
- a new project whose wanted style fits none of them (neo-brutalist, Swiss, retro-terminal...)
- an existing project with a coherent style of its own

In both, `DESIGN.md` records a **custom personality** and the checks follow it.

1. **`/design-brief` with a description**, e.g. `/design-brief "neo-brutalist, mono type, hard
   shadows"`, or `/design-brief custom` for an existing project. Claude writes `personality:
   custom — <label>` and a `## Personality` table that defines the style by the same ingredients
   the seven use: typography, colour, images, icons, shadows, border-radius, layout. For an
   existing project, it describes what the code already does and takes the tokens from it: the
   families, radii, spacing and font sizes in use.
2. **Relax what the style breaks on purpose.** Claude proposes a `relax` list of guideline rules
   the style breaks deliberately, for example `SHADOW-03` for hard black shadows or `TYPO-13` for
   justified columns. You confirm it, and each rule gets a reason under `## Relaxed rules`. Relaxed
   rules are no longer reported, and the audit lists them so a clean result is never misleading.
3. **Everything else keeps working against your tokens.** Spacing, radius, type scale, fonts and
   icon pack are checked against the brief's values, not the defaults, and the reviewer agents
   judge consistency with the custom ingredient table.

Two rules cannot be relaxed whatever the style: **contrast (`COLOR-11`)** and **body-text size
(`TYPO-05`)**. If either is listed in `relax`, it is still reported and the audit says so.

### Other common cases

- **Adding a page to a project that has a brief.** No command needed: ask for the page. The rules
  are injected before the first write and the result is linted against `DESIGN.md`. Run
  `/design-audit <the page>` when it is done, for the judgement review.
- **Reviewing a branch or PR.** `/design-audit` with no arguments covers uncommitted work. For
  committed changes on a branch, give the changed files as paths, or describe the area they
  belong to.
- **Rebranding.** Run `/design-brief` to update the personality and tokens, ask Claude to update
  the token definitions in code, then `/design-audit <path> --lint-only` to find everything still
  using the old values (`TYPO-02` and `ICON-02` list fonts and packs that are no longer in the
  brief).
- **Copy and structure only.** Ask "review the copy and structure of the landing page". That
  matches the `ux-reviewer` agent: CTA wording, headline, jargon, scannability, forms, layout
  patterns. No CSS values.
- **Pre-commit gate.** `sh <plugin>/scripts/audit.sh --dirty --strict` exits 1 when uncommitted web
  files have findings. Lint-only, with no model involved, so it is fast enough for a hook.

## Commands

### `/design-brief [personality | custom | "description"]`

**Decides the design and writes it down.** It does not check code.

| | |
|---|---|
| Argument | Optional. A personality slug (`serious-elegant`, `minimalist-simple`, `plain-neutral`, `bold-confident`, `calm-peaceful`, `startup-upbeat`, `playful-fun`), `custom`, or a free description of the style you want |
| Reads | `DESIGN.md` if present; the README, existing pages and `package.json` to learn what the site is for |
| Asks you | Only what it cannot infer: purpose, audience, desired feeling. One short round at most. It does not ask you to pick a style; it recommends one |
| Writes | `DESIGN.md`: personality with a one-line reason (and an ingredient table for a custom one), audience and goal, relaxed rules with reasons, and the `tokens` block |
| Offers | To mirror the tokens into existing stylesheets, the Tailwind theme, or a theme object |

Steps:

1. If `DESIGN.md` exists, it summarises it and asks what should change, then edits only that.
2. Otherwise it works out purpose and audience, asking only what is missing.
3. It settles the personality (the `choosing-a-website-personality` skill):
   - **You named one of the seven:** it is used, with a warning if it fits the audience poorly.
   - **You described a style:** it is matched to one of the seven or a blend, or recorded as
     custom when none fits.
   - **Nothing given:** it recommends one, or custom if none fits.
   - **Existing project that fits none:** its own style is recorded as custom.
4. It derives the tokens: from the personality's table, from the custom ingredient table, or from
   the values already in the code.
5. It proposes rules to relax, for a style that breaks guideline rules on purpose, and confirms
   them with you.
6. It writes `DESIGN.md` in the `writing-a-design-brief` format.

It finishes with a three-line summary: personality, typeface(s) and main colour, icon pack.

### `/design-audit [path or description] [--dirty] [--lint-only]`

**Checks code against the rules and `DESIGN.md`.** It does not decide the design, and it changes
nothing unless you then ask for fixes.

| Argument | Meaning |
|---|---|
| *(none)* | The uncommitted working tree: web files that differ from `HEAD`, plus untracked ones |
| A path | Files or directories, e.g. `src/pages/pricing` |
| A description | A page, section or component in plain words: "the pricing page", "checkout form" |
| `--dirty` | Same as no path: only uncommitted web files |
| `--lint-only` | Run the linter and skip the agents |

Steps:

0. **Resolve the target.** Paths are used as given. A description is resolved to files: the
   matching route or page, the components it renders, and the stylesheets they import. Shared
   layout and design-system files are left out unless the description is about them. The files are
   listed to you in one line before the audit. If nothing plausible matches, or two areas match
   equally, it asks.
1. **Lint (always).** Runs `scripts/audit.sh` on the target: the 21 measurable rules below. No AI
   reads the files in this step.
2. **Judgement review**, for no path or 30 files or fewer, and no `--lint-only`. Starts
   `design-reviewer`, and `ux-reviewer` too when the target has markup, in parallel. When step 0
   resolved a section inside a larger file, both agents are told to focus on it. Above 30 files
   the agents are skipped and you are told to narrow the target.
3. **Report.** One merged report, most severe first, grouped by file, every finding labelled with
   its rule ID, ending with the personality verdict and the five-second UX verdict.

**Why `--lint-only` exists:** the lint is fast, deterministic and works on any size of target; the
agents are slower, cost more, and can only read a limited number of files well. Use the lint alone
to size a problem or track progress, and the full audit to review a page.

**Limit:** the lint works on whole files. Auditing "the hero section" in `Home.tsx` lints all of
`Home.tsx`; only the agents can narrow to the section.

## Skills

Each skill holds one area's rules as a short numbered list (the part the hooks inject) followed by
longer guidance with examples. Skills load automatically when a task matches; all but the first
two only load when web files are involved (`paths` gating). The first two are entry points, so
they have to be reachable before any file exists.

| Skill | Covers | Loads when | Linted as |
|---|---|---|---|
| `choosing-a-website-personality` | The 7 personalities and what each implies for typeface, colour, images, icons, shadows, radius and layout; how to pick one, blend two, or define a custom one when none fits | A site or page is being designed, or a look and feel is asked for | — |
| `writing-a-design-brief` | The `DESIGN.md` format and its machine-read `tokens` block | `DESIGN.md` is created or its tokens change; `/design-brief` | — |
| `setting-typography` | One or two proven typefaces, a type scale, 16–32px body text (20px+ for long reads), weight ≥ 400, under 75 characters a line, line-height 1.5–2, no justified or long centred text | Fonts, sizes, weights, line-height or alignment are written | `TYPO-02 04 05 08 09 10 13` |
| `building-color-palettes` | Main colour plus grey, tints and shades defined once as tokens, colour for emphasis, no pure black, 4.5:1 contrast | Colours, themes or backgrounds are chosen | `COLOR-02 03 10 11` |
| `using-images-and-illustrations` | Relevant, original-looking images, real people, three ways to put text over an image, 2x resolution, compression, matching sizes side by side | Images, heroes, galleries or backgrounds are added | `IMG-12` |
| `using-icons` | One SVG icon pack matched to the type, icons with text, labelled actions, text-coloured by default, enclosed in a shape rather than scaled up | Icons or an icon library are added | `ICON-02 03` |
| `applying-shadows-and-radius` | Shadows only if the personality allows, light, sparse, sm/md/lg by element size, changing on hover; radius matched to the typeface and taken from a small fixed set | `box-shadow` or `border-radius` is written | `SHADOW-02 03`, `RADIUS-04` |
| `spacing-with-whitespace` | More space between sections than groups, and groups than elements; proximity; space instead of lines; a fixed spacing scale | Margin, padding or gap is written, or a layout is spaced | `SPACE-08` |
| `establishing-visual-hierarchy` | Important things first, images used mindfully, emphasis through size, weight, colour and whitespace, de-emphasising neighbours | A page or section is laid out, or elements compete for attention | — (agents only) |
| `designing-for-user-experience` | Familiar patterns, a prominent and descriptive CTA, links-only underline, 200–500ms animations, single-column forms, feedback, plain copy | CTAs, forms, navigation, animation or copy are written | `UX-02 03 04` |
| `composing-components-and-layouts` | A catalogue of components and layout patterns, and how to assemble a page from them | A page or section is structured from components | — (agents only) |

Reference files next to the skills hold the longer material: the per-personality tables, a sample
type scale, a palette template, the spacing scale, and the component and layout catalogue.

## Agents

Both are read-only (`Read, Grep, Glob, Bash`): they report, they never edit.

| Agent | Reviews | Starts when |
|---|---|---|
| `design-reviewer` | Personality fit and areas 01–08: typeface choice, use of the main colour, image relevance and text over images, icon fit, shadow and radius fit, whitespace grouping, visual hierarchy. Runs `audit.sh` first and confirms its findings, but spends its effort on what the script cannot measure | `/design-audit` on a small target, or when you ask for a design review or critique |
| `ux-reviewer` | Areas 09–10: CTA prominence and wording, link styling, animation purpose, form layout and feedback, button placement, headline clarity, fluff and jargon, scannability, layout patterns. Structure and words, not CSS values | `/design-audit` on a target with markup, or when you ask for a UX or copy review |

Both read `DESIGN.md` first. Each finding comes with `path:line`, the rule ID, what was observed,
and a concrete fix (with suggested wording for copy). When nothing violates the rules, they say so
in one line.

## Hooks

The hooks run on their own. None of them blocks anything: every path exits 0, and what they have
to say reaches Claude as context. See [hooks.md](../hooks.md) for the shared exit-code contract.

| Event | Script | What it does | Stays silent when |
|---|---|---|---|
| `SubagentStart` | `inject-rules.sh` | Gives a subagent the rules digest, since a fresh subagent never loads the skills itself | The project has no markup, stylesheets or `DESIGN.md` |
| `UserPromptSubmit` | `snapshot-turn.sh` | Records a checksum of every uncommitted web file, the baseline the Stop hook compares against | Not a git repository; the prompt was not typed by a person (a background task waking the session) |
| `UserPromptSubmit` | `route-prompt.sh` | When a prompt is about design ("landing page", "new screen", "CSS", "redesign", "font"…), tells Claude to settle the personality first and to read `DESIGN.md`. When there is no `DESIGN.md` and the request builds new pages, screens or several components, Claude tells you so **before writing anything** and asks: create it now with `/design-brief`, or let Claude decide the style. A small UI change gets a one-line mention instead. In plan mode it adds the rules digest | The prompt is not about design; it already fired this session |
| `PreToolUse` on `Write\|Edit\|MultiEdit\|ExitPlanMode` | `inject-write-rules.sh` | Gives Claude the rules digest just before its first write to markup or a stylesheet, or when a design plan is accepted. Without `DESIGN.md`, the first **new** page or stylesheet of the session also triggers the create-or-decide question (a backstop for prompts that did not read as design work; Claude skips it if you already answered). Editing an existing file only gets a one-line mention | The file is not markup or a stylesheet (a plain `.ts` edit pays nothing); the digest and the question were already given this session |
| `PostToolBatch` | `check-batch.sh` | Lints the web files a batch of writes just produced and asks Claude to fix the findings now. A `Write` owns the whole file; an `Edit` only the lines it wrote | Nothing web was written; no new findings |
| `Stop` | `check-turn.sh` | Lints every web file the request changed, however it was written (shell commands and subagents included), runs the cross-file checks (fonts, icon packs), and asks Claude to mention `/design-audit` in its summary, once per request | Nothing changed; nothing new to say. It never starts the agents itself |

How they avoid noise and loops:

- **Said once.** A finding is keyed by rule, file, selector, property and value, not by line, and
  recorded per request in a set the batch and Stop hooks share. The digest is given once per
  session, whichever trigger fires first.
- **Only this request's work.** `Stop` lints files whose content changed since the snapshot, so a
  page someone else left uncommitted is never reported. A new prompt you type starts a new request
  and a new baseline.
- **Stop ends.** Findings are recorded as they are told and the `/design-audit` pointer is given
  once per request, so a yield with nothing new is silent and the conversation can finish.
- **The digest fits.** It is built from each skill's numbered rules only, personality first, and
  stays under the 7000-character budget with room to spare. `test_inject.sh` checks that the last
  rule line arrives intact on every path.

State lives in `${TMPDIR:-/tmp}/web-design/<session>.*`.

## Personalities

| Personality | In short | Typical industries |
|---|---|---|
| Serious/Elegant | Thin serif type, gold or pastel colours, big high-quality images | Real estate, high fashion, jewellery, luxury |
| Minimalist/Simple | Small black sans-serif text, lines, few images or icons | Fashion, portfolios, writing-first sites |
| Plain/Neutral | Neutral small type, very structured layout | Big corporations, government |
| Bold/Confident | Big bold type, big blocks of bright colour | Agencies, startups, travel |
| Calm/Peaceful | Pastels, soft serif headings, matching imagery | Healthcare, wellness |
| Startup/Upbeat | Medium sans-serif, light-grey text and backgrounds, rounded elements | SaaS, modern tech |
| Playful/Fun | Colourful and round, hand-drawn illustrations, animation | Children's products, pets, food |
| Custom | Whatever the brief's ingredient table defines | Anything the seven do not cover |

A personality changes *which* typeface, colour or radius is used. Two rules hold for every style,
custom ones included, and cannot be relaxed: contrast 4.5:1 and body text 16px or larger. The
other guideline rules are defaults that a custom style may relax in `DESIGN.md`, with a reason.

## `DESIGN.md`

The brief lives at the project root. Prose is for people and agents; the fenced `tokens` block is
also read by the hooks:

````markdown
```tokens
personality: startup-upbeat
font-families: Inter
icon-pack: lucide
type-scale: 12 14 16 18 20 24 30 36 44 52 62
spacing-scale: 2 4 8 12 16 24 32 48 64 80 96 128
palette: primary #4f46e5; grey #334155; accent #f59e0b
radius: 4 8 16 9999
shadows: sm 0 1px 3px rgba(0,0,0,.1); md 0 4px 12px rgba(0,0,0,.08)
```
````

| Key | Used by |
|---|---|
| `font-families` | The linter: any other family is flagged as `TYPO-02` |
| `icon-pack` | The linter: any other pack is flagged as `ICON-02` |
| `spacing-scale` | The linter: replaces the default scale for `SPACE-08` |
| `type-scale` | The linter: any literal font-size off the scale is flagged as `TYPO-04` (fluid `clamp()` sizes and Tailwind's own scale are exempt) |
| `radius` | The linter: any border-radius off the scale is flagged as `RADIUS-04`. `0` and percentages are always allowed; a value of 999+ allows pills |
| `relax` | The linter and the agents: these rule IDs are not reported. `COLOR-11` and `TYPO-05` cannot be relaxed |
| `personality` | People and the agents: a slug such as `startup-upbeat`, or `custom — <label>` |
| `palette`, `shadows` | People and the agents |

Without a brief the linter falls back to the generic rules, and Claude asks you once per session,
before building new pages, whether to create one or let it decide the style.

**When you are asked.** The question comes from the prompt hook, before any code is written,
whenever a design request builds new pages, screens or several components. If the prompt did not
read as design work, the write hook asks at the first new page or stylesheet instead; that hook
runs as the write happens, so in that case the question arrives after that first file. Small edits
to existing UI never trigger the question, only a one-line mention. If you let Claude decide, it
names the personality and tokens before building; nothing is written to `DESIGN.md` unless you
ask, so a later session will ask again.

## What the linter measures

The linter (`scripts/audit.sh`, also run by the hooks) reads CSS/SCSS/LESS, `<style>` blocks,
`style=""`, JSX `style={{…}}`, styled-components/emotion templates, and Tailwind classes, and turns
all of them into the same records. So `font-weight: 300`, `fontWeight: 300` and `font-light` are
the same finding. Custom properties, SCSS `$vars` and LESS `@vars` are resolved. `.sass` (indented
syntax) is not read.

| ID | Flags |
|---|---|
| `COLOR-11` | Contrast below 4.5:1 (3:1 at 24px+, or 18.66px+ bold) where one rule, inline style or element sets both text colour and background |
| `TYPO-08` | `font-weight` below 400, `lighter`, `font-thin/extralight/light` |
| `COLOR-10` | Pure black text |
| `TYPO-05` | Body-text selectors (`body, p, li, article, blockquote, dd`) under 16px; captions and labels exempt; a 62.5% root is honoured |
| `TYPO-10` | Line-height outside 1.5–2 on body text |
| `TYPO-13` | Justified text |
| `UX-04` | Transition or animation durations outside 200–500ms (infinite loops exempt) |
| `UX-03` | Underlines on selectors that are not links |
| `UX-02` | Vague button or link text: "click here", "here", "submit", "go", "ok" |
| `ICON-02` | More than one icon pack across the files checked, or one other than DESIGN.md's |
| `ICON-03` | Icons served as `.png/.jpg` |
| `TYPO-02` | More than two font families, or one not in DESIGN.md |
| `SHADOW-03` | Neutral shadow colours above 0.25 alpha, or a shadow with no colour |
| `COLOR-02` | CSS named colours (except `white`, `transparent`, `currentColor`) |
| `TYPO-09` | A text measure over ~75 characters |
| `TYPO-04` | A font-size off DESIGN.md's `type-scale`; without one, more than 12 distinct font sizes in a file |
| `COLOR-03` | More than 16 distinct raw colour literals in a file |
| `SHADOW-02` | More than 4 distinct box-shadows in a file |
| `RADIUS-04` | A border-radius off DESIGN.md's `radius` scale; without one, more than 4 distinct radii in a file |
| `IMG-12` | Neighbouring images with different `width`/`height` |
| `SPACE-08` | Margin, padding or gap off the spacing scale |

The table runs in report order, most important to a reader first. Findings of one rule in one
file collapse into a single line, so thirty off-scale paddings cost one line and cannot crowd out a
contrast failure. Every finding is advisory: a rule bent on purpose for the personality can be
kept, with a one-line reason. A rule the style breaks every time belongs in DESIGN.md's `relax`
instead, so it stops being reported.

**Tailwind** classes are read only when the project uses Tailwind (`tailwind.config.*`, or
`tailwindcss` in `package.json`). Standard utilities are already on Tailwind's scales, so they are
exempt from the scale and sprawl checks; arbitrary values like `p-[13px]` are not. Colours resolve
for the neutral families (slate, gray, zinc, neutral, stone) plus white and black, which is where
text contrast usually fails. A brand colour class is not resolved, so its contrast is not checked,
but it never produces a false finding.

**Not measured:** personality fit, hierarchy, image relevance, whitespace grouping, icon meaning,
headline and copy quality, form layout. Those belong to the two agents.

## Running the linter by hand

```
sh plugins/web-design/scripts/audit.sh src/              # a directory (git-listed in a repo)
sh plugins/web-design/scripts/audit.sh --dirty           # only uncommitted web files
sh plugins/web-design/scripts/audit.sh src/ --top 20     # at most 20 finding groups
sh plugins/web-design/scripts/audit.sh --dirty --strict  # exit 1 on findings: a pre-commit gate
```
