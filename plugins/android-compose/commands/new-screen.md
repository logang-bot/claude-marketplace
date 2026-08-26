---
name: new-screen
description: Scaffold a Compose screen, its ViewModel, route registration, and light/dark previews
argument-hint: <ScreenName> [feature-package]
---

Scaffold a new Compose screen named `$1`, in feature package `$2` if given, otherwise inferred
from the screen name.

Before writing anything, read the existing screens to match this project's conventions rather
than assuming them — find a recent screen with `Glob` on the UI package, and read it along with
its ViewModel and the navigation graph. Match the package layout, DI setup, state-holder
pattern, and navigation style you find there. Do not introduce a different architecture.

Produce:

1. **`$1.kt`** — the screen composable. It creates its own ViewModels; `Modifier` is the first
   optional parameter and is passed to the root element; no business logic in the composable.
   Split into focused child composables rather than one long body.
2. **`$1ViewModel.kt`** — UI state only. Anything that coordinates repositories, enforces a
   domain rule, or performs a domain calculation goes into a UseCase instead.
3. **Route registration** in the existing navigation graph, passing only primitives. No
   `LaunchedEffect`, `remember`, or state initialization in the nav file.
4. **Previews** in the same file as the screen: `$1Preview` with
   `uiMode = Configuration.UI_MODE_NIGHT_NO` and `$1DarkPreview` with
   `UI_MODE_NIGHT_YES`.
5. **`strings.xml` entries** for every user-facing string; reference them with
   `stringResource(R.string.…)`.

If `$1` is empty, ask for the screen name instead of guessing.

Report which files you created or modified. Then tell the user to build, rather than claiming
it compiles — you have not run the build.
