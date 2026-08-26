# `android-compose`

Android, Kotlin, and Jetpack Compose conventions: how composables are structured, where state
and business logic live, how routes are registered, and where user-facing text goes.

**Install it in Android projects only.** Every skill is gated with `paths`, so the plugin stays
silent in a repo with no Kotlin — but there is no reason to carry it where it cannot apply.

## Components

| Kind | Name | Fires when |
|---|---|---|
| Skill | `creating-composables` | `**/*.kt` — writing a `@Composable` function |
| Skill | `creating-preview-of-composable` | `**/*.kt` — writing a preview |
| Skill | `creating-or-updating-screen-routes` | `**/*.kt` — touching a navigation graph |
| Skill | `writing-user-facing-strings` | `**/*.kt`, `**/*.xml` — writing user-facing text |
| Skill | `identifying-use-cases` | `**/*.kt` — deciding where logic belongs |
| Agent | `android-architecture-reviewer` | Asked to review layering |
| Command | `/new-screen <Name> [package]` | Run explicitly |
| Command | `/extract-strings [path]` | Run explicitly |

No hooks. Everything here is advisory at authoring time or run on demand.

The `paths` values are what keep these quiet elsewhere — see
[../authoring.md](../authoring.md#paths-gating).

## Composables

`Modifier` is always the **first optional parameter**, and is passed to the root element of the
composable. There is no strict size limit on a composable body — the
[`general-code-style`](general-code-style.md#the-ui-component-exemption) length and parameter
rules explicitly exempt UI component functions — but prefer splitting into smaller, focused
child composables for readability and reuse.

Business logic does not belong in a composable. Move it to a ViewModel (UI state) or a UseCase
(domain logic).

## Previews

Every preview lives in **the same file** as the composable it previews, and comes in a light and
a dark variant:

| Variant | `uiMode` | Name |
|---|---|---|
| Light | `Configuration.UI_MODE_NIGHT_NO` | `<ComposableName>Preview` |
| Dark | `Configuration.UI_MODE_NIGHT_YES` | `<ComposableName>DarkPreview` |

Dark mode is skipped only when the composable explicitly does not support theming — a pure
layout with no colour references.

## Screens and routes

Two rules, both about keeping the navigation graph dumb:

1. **Screens create their own ViewModels.** The navigation composable passes only primitives —
   IDs, flags. Never a ViewModel instance.
2. **State and effects live in the screen.** `LaunchedEffect`, `remember`, and any other state
   initialization go inside the screen composable, not in the nav file.

## Strings

Any text displayed to the user is a resource in `strings.xml`, never a literal in source.
Retrieve it with `stringResource(R.string.key)` inside a composable, or
`context.getString(R.string.key)` elsewhere.

Explicitly **exempt** — these stay as literals:

- exception messages and error identifiers (internal, not user-facing)
- log and debug strings
- technical identifiers: keys, tags, route names, API field names, database column names

`/extract-strings [path]` automates the migration: it adds entries in the naming style already
used in that `strings.xml` (it reads the file first), reuses an existing key rather than adding
a duplicate, and reports both what it extracted and what it deliberately skipped so you can
check its judgement on the boundary cases. With multiple localized `strings.xml` files it edits
the default one only and tells you which translations now need updating.

## Use cases

The `identifying-use-cases` skill is the deepest of the five — it carries worked examples. In
short, extract a use case when the logic coordinates more than one repository, enforces a domain
rule, would be duplicated across ViewModels, has side effects beyond a single write, or performs
a domain-level calculation.

Do **not** extract one for a plain CRUD pass-through, for presentational logic (formatting,
sorting for display), or for a single repository call with no rule attached.

Naming is `<Verb><Noun>UseCase`. The skill deliberately does not assert where use cases live —
it tells you to find an existing `*UseCase.kt` and match its package and style, because that
varies per project. Same for the DI annotation.

## The reviewer

`android-architecture-reviewer` is read-only and checks five layering violations: business logic
in a composable, ViewModel instances crossing the navigation graph, state or effects in the nav
file, logic in a ViewModel that qualifies as a UseCase, and hardcoded user-facing strings.

It is told to read surrounding code before judging — the UseCase rule in particular depends on
what the code actually coordinates, not on how it is named — and to say so when a case is
genuinely borderline rather than reporting it flatly.

## `/new-screen`

Scaffolds a screen, its ViewModel, route registration, previews, and `strings.xml` entries.

Before writing anything it reads an existing recent screen, its ViewModel, and the navigation
graph, and matches the package layout, DI setup, state-holder pattern, and navigation style it
finds. It is instructed not to introduce a different architecture from the one already in the
project. It reports what it created and tells you to build, rather than claiming it compiles.
